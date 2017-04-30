
GENERATE	= hugo
SERVE		= hugo server --buildDrafts
OUTPUT_DIR	= public
SOURCE_BRANCH	= source
PUBLISH_BRANCH	= master

.PHONY: all
all: generate

.PHONY: generate		
generate: submodule-stamp output-stamp prepare ## Build the website to the output directory
	$(GENERATE)

submodule-stamp:
	git submodule init
	git submodule update
	touch $@

output-stamp:
	mkdir -p $(OUTPUT_DIR)
	git worktree add $(OUTPUT_DIR) master
	touch $@

.PHONY: prepare
prepare:			## Prepare the output directory
	cd $(OUTPUT_DIR) && find \! -name '.git*' -delete

.PHONY: clean
clean:				## Reset de output directory to original state
	cd $(OUTPUT_DIR) && git reset --hard

.PHONY: distclean
distclean:			## Remove the git worktree used to publish the website
	rm -rf $(OUTPUT_DIR) output-stamp
	git worktree prune

.PHONY: maintainer-clean	
maintainer-clean: distclean	## Does a full cleanup, like after a non recursive git clone
	git submodule deinit --all
	rm -f submodule-stamp

.PHONY: serve			
serve: submodule-stamp		## LiveReload mode
	$(SERVE)

.PHONY: publish
publish: generate		## Publishes the website to github page
	@cd $(OUTPUT_DIR) || { printf "\033[1;91mMissing output directory\033[0m\n";exit 4;};	\
	if [ -z "$$(git status --porcelain)" ]; then					\
		printf "\033[1;92m= Nothing to publish =\033[0m\n";			\
		exit 0;									\
	else										\
		git add . && git commit -m "New publishing the $$(date)" &&		\
		git push origin master ||						\
		{ printf "\033[1;91m/!\\ Something is wrong /!\\\033[0m\n";exit 8;};	\
	fi;										\
	printf "\033[1;92m= Publishing done =\033[0m\n";				\
	exit 0;

.PHONY: help			
help: Makefile			## This help
	@awk -F':.*##[[:space:]]*' '/^[^:\t]*:.*##/{printf("%-20s%s\n",$$1,$$2)}' $<


