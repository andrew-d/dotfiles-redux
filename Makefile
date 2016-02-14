.PHONY: test
test: lint unit-test

.PHONY: lint
lint:
	@printf "\033[1;32m==> Running shellcheck\033[0m\n"
	@-shellcheck bin/install.sh
	@printf "\033[1;32m==> Running checkbashisms\033[0m\n"
	@-checkbashisms bin/install.sh
	@printf "\033[1;32m==> Linting done\033[0m\n"

.PHONY: unit-test
unit-test: test/*

test/%: force
	@printf "\033[1;32m==> Running test: $@\033[0m\n"
	@printf "\033[1;34m -> bash\033[0m\n"
	@bash "$@"
	@printf "\033[1;34m -> dash\033[0m\n"
	@dash "$@"

.PHONY: force
force: ;
