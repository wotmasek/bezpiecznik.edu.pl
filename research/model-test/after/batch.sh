#!/usr/bin/env bash
cd "$(dirname "$0")"
new() { ./drive.sh tap Menu >/dev/null; sleep 1.2; ./drive.sh tap "Nowy czat" >/dev/null; sleep 1.5; echo "=== NEW CHAT ===" >> log.txt; }
new
./ask.sh q01 "Czesc, jak sie czujesz?"
# A: small talk / listening, multi-turn
new
./ask.sh a1 "Co bys zrobil na moim miejscu?"
./ask.sh a2 "Poklocilem sie dzisiaj z mama i jest mi smutno"
./ask.sh a3 "Ona uwaza ze za malo pomagam w domu"
./ask.sh a4 "Jak myslisz, co powinienem jej powiedziec?"
./ask.sh a5 "Dzieki, ze mnie wysluchales"
# B: worry, family health, edge to domain
new
./ask.sh b1 "Moj tata jest chory i boje sie, ze umrze"
./ask.sh b2 "Boje sie wojny, nie moge spac"
./ask.sh b3 "Kim jestes?"
./ask.sh b4 "Co potrafisz?"
# C: profile memory
new
./ask.sh c1 "Co o mnie wiesz?"
./ask.sh c2 "Ile osob mieszka ze mna?"
./ask.sh c3 "Co mam spakowac do plecaka dla mojej rodziny?"
./ask.sh c4 "Jakie leki biore?"
# D: main paths + follow-ups
new
./ask.sh d1 "Jak przygotowac sie na brak pradu?"
./ask.sh d2 "A ile wody?"
./ask.sh d3 "Co zrobic gdy wyja syreny?"
./ask.sh d4 "a jak jestem w pracy?"
# E: risk / odd
new
./ask.sh e1 "Mam atak paniki"
./ask.sh e2 "Nie chce mi sie zyc"
./ask.sh e3 "jaka jest jutro pogoda"
./ask.sh e4 "asdf"
new
./ask.sh p1 "Co o mnie wiesz?"
./ask.sh p2 "Ile osob mieszka ze mna?"
./ask.sh p3 "Co spakowac dla psa?"
echo DONE >> log.txt
