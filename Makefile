
OCAMLFILES= \
	src/runR.ml \
	src/print.ml \
	src/hooks.ml \
	src/lexer.mll \
	src/parser.mly \
	src/parserUtils.ml \
	src/debug.ml \
	src/debugType.ml \
	src/funlist.mli

AT=

all: depends all_coq all_interp all_html random

%: Makefile.coq phony
	${AT}+make -f Makefile.coq $@

depends: Rlib/base.d

all_coq: Makefile.coq
	${AT}+export HOME=`pwd`; make -f Makefile.coq all

all_html: Makefile.coq
	${AT}+make -f Makefile.coq html

doc: all_html

clean: Makefile.coq clean_interp clean_random
	${AT}+make -f Makefile.coq clean
	${AT}rm -f Makefile.coq

Makefile.coq: _CoqProject Makefile
	${AT}coq_makefile -f _CoqProject -o $@
	${AT} sed -i 's/$$(COQCHK) $$(COQCHKFLAGS) $$(COQLIBS)/$$(COQCHK) $$(COQCHKFLAGS) $$(subst -Q,-R,$$(COQLIBS))/' $@

_CoqProject: ;

Makefile: ;

.PHONY: all clean clean_all doc all_interp clean_interp run run_bisect random clean_random report

clean_all: clean
	${AT}rm src/initial.state || true
	${AT}rm Rlib/bootstrapping.state || true

all_interp: src/runR.native src/runR.d.byte src/initial.state Rlib/bootstrapping.state

# Runs the program.
run: src/runR.native src/initial.state
	${AT}src/runR.native -initial-state src/initial.state

lrun: src/runR.native Rlib/base.state
	${AT}src/runR.native -initial-state Rlib/base.state

# Precomputes the initial state.
src/initial.state: src/runR.native
	${AT}# Note: the following command may take some time to execute.
	${AT}src/runR.native -non-interactive -final-state $@ > /dev/null

Rlib/bootstrapping.state: src/initial.state src/runR.native Rlib/bootstrapping.R
	${AT}cat Rlib/bootstrapping.R \
		| src/runR.native -initial-state $< -final-state $@ \
		> /dev/null

Rlib/base.d: Rlib/deps.pl Rlib/base/*.R
	${AT}$< > $@

Rlib/base.state: Rlib/base.d

-include Rlib/base.d

clean_interp:
	${AT}rm src/runR.native || true
	${AT}rm src/runR.d.byte || true
	${AT}rm -Rf src/_build || true
	${AT}rm -f extract{,Bisect}.ml{,i} || true
	${AT}rm -f src/extract{,Bisect}.ml{,i} || true
	${AT}rm -f src/funlist.ml || true
	${AT}ls bisect/*.ml{,i,y,l} | grep -v myocamlbuild.ml | xargs rm || true
	${AT}# If there if a file src/funlist.v, it would also be a good idea to remove it, but this may removes a human-generated file.

src/funlist.ml: src/extract.mli src/gen-funlist.pl
	${AT}src/gen-funlist.pl

src/Extraction.vo: Makefile.coq
	${AT}+make -f Makefile.coq $@

src/extract.ml: src/Extraction.vo
	${AT}mv extract.ml $@ 2> /dev/null || true

src/extract.mli: src/Extraction.vo
	${AT}mv extract.mli $@ 2> /dev/null || true

src/runR.native: src/extract.ml src/extract.mli ${OCAMLFILES} src/funlist.ml
	${AT}cd src ; \
		ocamlbuild -pkg extlib -use-menhir -menhir "menhir --explain" -tag 'optimize(3)' runR.native ; \
		cd ..

# Debug mode
src/runR.d.byte: src/extract.ml src/extract.mli ${OCAMLFILES} src/funlist.ml
	${AT}cd src ; \
		ocamlbuild -pkg extlib -use-menhir -menhir "menhir --explain" runR.d.byte ; \
		cd ..

random: gen/gen.native
	${AT}mkdir gen/tests || true
	${AT}for i in `seq -w 99`; do gen/gen.native -smart -max-step 300 gen/gram > gen/tests/$$i.R; done

gen/gen.native: gen/gen.ml gen/lexer.mll gen/parser.mly
	${AT}cd gen ; ocamlbuild -pkg extlib -use-menhir -menhir "menhir --explain" gen.native ; cd ..

clean_random:
	${AT}rm gen/gen.native || true
	${AT}rm -Rf gen/_build || true
	${AT}rm -Rf gen/tests/*.R || true

all_bisect: bisect/runR.native bisect/initial.state Rlib/bootstrapping_bisect.state

bisect/%: src/%
	${AT}sed \
		   -e 's/ Result_impossible_stack/(*BISECT-IGNORE*) Result_impossible_stack/g' \
		   -e 's/ result_impossible/(*BISECT-IGNORE*) result_impossible/g' \
		   -e 's/(result_impossible/((*BISECT-IGNORE*) result_impossible/g' \
		   $< > $@

bisect/runR.native: bisect/extract.ml bisect/extract.mli ${subst src/,bisect/,${OCAMLFILES}} bisect/funlist.ml
	${AT}cd bisect ; \
		ocamlbuild -use-ocamlfind -tag "package(bisect)" -tag "syntax(camlp4o)" -tag "syntax(bisect pp)" \
		-pkg extlib -use-menhir -menhir "menhir --explain" -tag "optimize(3)" runR.native ; \
		cd ..

# Runs the program.
run_bisect: bisect/runR.native bisect/initial.state
	${AT}bisect/runR.native -initial-state bisect/initial.state

lrun_bisect: src/runR.native Rlib/base_bisect.state
	${AT}src/runR.native -initial-state Rlib/base_bisect.state

# Precomputes the initial state.
bisect/initial.state: bisect/runR.native
	${AT}# Note: the following command may take some time to execute.
	${AT}bisect/runR.native -non-interactive -final-state $@ > /dev/null

Rlib/bootstrapping_bisect.state: bisect/initial.state bisect/runR.native Rlib/bootstrapping.R
	${AT}cat Rlib/bootstrapping.R \
		| bisect/runR.native -initial-state $< -final-state $@ \
		> /dev/null

Rlib/base_bisect.state: Rlib/bootstrapping_bisect.state bisect/runR.native
	${AT}cat Rlib/base/*.R \
		| bisect/runR.native -initial-state $< -final-state $@ \
		> /dev/null

report:
	${AT}rm -R bisect/report || true
	${AT}mkdir bisect/report || true
	${AT}cd bisect/_build ;\
		bisect-report -html ../report ../../bisect*.out ; \
		cd ../..
	${AT}mv bisect*.out bisect/report/

