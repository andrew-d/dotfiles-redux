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
unit-test: test/test_*
	@printf "\033[1;32m==> bash\033[0m\n"
	@bash test/roundup $^
	@printf "\033[1;32m==> dash\033[0m\n"
	@dash test/roundup $^

.PHONY: force
force: ;
