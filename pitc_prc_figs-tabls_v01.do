// working directory
cd "C:\Users\sharygin\Desktop\Data_and_Figures"

// define color schemes
// 1. 3-way 
global c1="forest_green*.9"
global c2="orange*.9"
global c3="eltblue*.9"

// prerequisites
foreach in "tablecol" {
	cap which "`p'"
	if _rc ssc install `p'
}

// assemble unified dataset for figures/tables.
import delim using "2023\Data and Tables - Multnomah\MultCo_PIT_2023.csv", clear 
gen int county=51
save hrac_pitc23_data.dta, replace
import delim using "2023\Data and Tables - Clackamas\ClackCo_PIT_2023.csv", clear 
tostring group_id, replace
gen source="Survey"
gen int county=5
append using hrac_pitc23_data.dta
gen int year=2023
save hrac_pitc23_data.dta, replace

// cleaning
lab def c 5 "Clackamas" 51 "Multnomah" 67 "Washington", replace
label values county c
gen hhsize=hh_size
replace hhsize=strofreal(hh_size2) if real(hh_size)==. & hh_size2<.
destring hhsize, replace
encode hh_type, gen(hhtype)
lab def g 1 "Male" 2 "Female" 3 "No Single Gender" 4 "Questioning" 5 "Transgender", replace
encode gender, gen(genderrc) label(g) noextend
replace ethnicity="Hispanic/Latin(a)(o)(x)" if ethnicity=="Hispanic or Latin(a)(o)(x)"
lab def h 0 "Non-Hispanic/Non-Latin(a)(o)(x)" 1 "Hispanic/Latin(a)(o)(x)", replace
encode ethnicity, gen(hispanrc) label(h) noextend
lab def r 1 "White" 2 "Black, African American, or African" 3 "American Indian, Alaska Native, or Indigenous" ///
	4 "Asian or Asian American" 5 "Native Hawaiian or Pacific Islander" 6 "Multiple", replace
encode race, gen(racerc) label(r) noextend
lab def v 0 "No" 1 "Yes", replace
for var veteran chronic sud hiv dv mh: encode X, gen(Xrc) label(v) noextend
destring *_hh, replace ignore("Inf")
lab def a 1 "Under 18" 2 "18-24" 3 "25-34" 4 "35-44" 5 "45-54" 6 "55-64" 7 "65+", replace
encode age, gen(agecat) label(a) noextend
foreach v in "ES Emergency shelter" "TH Transitional housing" "US Unsheltered" {
	tokenize "`v'"
	replace status=trim("`2' `3'") if status=="`1'"
}
lab def s 1 "Unsheltered" 2 "Emergency shelter" 3 "Transitional housing", replace
encode status, gen(statusrc) label(s) noextend
encode source, gen(sourcerc)
drop hh_size hh_size2 hh_type gender age ethnicity race veteran chronic sud hiv dv mh status source
rename *rc *

// labels
lab var id "PIT uid"
lab var group_id "HHID"
lab var hhtype "adult/child/family"
lab var hhsize "N in HH (hh_size or hh_size2 iff missing)"
lab var hoh "HH head?"
lab var agecat "<18/18-24/25-34/35-44/45-49/55-64/65+)"
lab var gender "gender (f/m/n/q/t)"
lab var veteran "veteran?"
lab var chronic "chronic homeless?"
lab var mh "mental health disorder?"
lab var sud "substance use disorder?"
lab var hiv "AIDS or HIV?"
lab var dv "victim of DV?"
lab var source "HMIS or survey (ONSC)"
lab var hispan "Hispanic/Latin(a)(o)(x)?"
lab var race "race (w/n/b/a/p/m/.)"
lab var vet_hh "veteran in hh?"
lab var youth_hh "youth age<25 in hh?"
lab var child_hh "child age<18 in hh?"
lab var chronic_hh "chronic homeless person in hh?"
lab var parenting_child "family hh w/child <18?"

// save
expand 2, gen(dummy) // dummy data for 2022
replace year=2022 if dummy==1
save hrac_pitc23_data.dta, replace

// page21/table2
use status county year if year==2023 using hrac_pitc23_data.dta, clear
tablecol status if year==2023, colpct by(county)

// page22/table3
use status county year using hrac_pitc23_data.dta, clear
tablecol status year, colpct by(county)

// page22/fig2
use status county year using hrac_pitc23_data.dta, clear
qui tablecol status year, colpct by(county) replace
egen total=sum(__tc11), by(county year)
gen shr=__tc11/total
drop __tc11 total
reshape wide shr, i(county year) j(status)
qui for var shr*: replace X=X*100
gen lab1=shr1
gen lab2=shr2
gen lab3=shr3
tostring lab*, format(%2.1f) force replace
for var lab*: replace X=X+"%"
replace shr2=shr1+shr2
replace shr3=shr2+shr3 
gen laby1=(shr1)/2
gen laby2=(shr1+shr2)/2
gen laby3=(shr2+shr3)/2
tw  (bar shr3 year, mla(shr3) mlabpos(6) barw(0.85) lc($c3 ) fc($c3 )) ///
	(bar shr2 year, mla(shr2) mlabpos(6) barw(0.85) lc($c2 ) fc($c2 )) ///
	(bar shr1 year, mla(shr1) mlabpos(6) barw(0.85) lc($c1 ) fc($c1 )) ///
	(scatter laby3 year, ms(none) mla(lab3) mlc(gs11) mlabpos(0) legend(off)) ///
	(scatter laby2 year, ms(none) mla(lab2) mlc(gs11) mlabpos(0) legend(off)) ///
	(scatter laby1 year, ms(none) mla(lab1) mlc(gs10) mlabpos(0) legend(off)), ///
	by(county, ti("{bf:FIGURE 2.} Share of People Sheltered and Unsheltered") ///
	   note("Source: PIT count 2022 and 2023", margin(top)) ///
	   legend(ring(1) pos(6))) ///
	subtitle(,bcolor(none)) ///
	xla(2021.25 " " 2022 2023 2023.75 " ", nogrid) yla(0(10)100, nogrid) xti("") yti("") ///
	legend(order(3 "Unsheltered" 2 "Emergency shelter" 1 "Transitional housing") ///
		symy(*1.75) symx(*.75) r(1)) aspect(1)
graph save fig2.gph, replace
graph export fig2.emf, replace
