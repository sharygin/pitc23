// notes
** In general, the approach is to confirm other dataset to the format of the Multnomah County dataset
** Cannot reproduce the variables parenting_youth and parenting_child in all datasets
** Washington Co. sheltered is missing HIV status.

// working directory
cd "C:\Users\sharygin\Desktop\Data_and_Figures"

// prerequisites
foreach p in "tablecol" "bigtab" {
	cap which "`p'"
	if _rc ssc install `p'
}

/***
 *        __  _        ___   ____  ____  
 *       /  ]| |      /  _] /    ||    \ 
 *      /  / | |     /  [_ |  o  ||  _  |
 *     /  /  | |___ |    _]|     ||  |  |
 *    /   \_ |     ||   [_ |  _  ||  |  |
 *    \     ||     ||     ||  |  ||  |  |
 *     \____||_____||_____||__|__||__|__|
 *                                       
 */

/*
// fix washington 2023 before merging
** 0427_sheltered_Data_Washington.xlsx: tab "Sheltered_Client"
** 0427_sheltered_Data_Washington.xlsx: tab "Disability Detail"
** 0427_Unsheltered_Data_Washington.xlsx: tab "additional count"
** 0427_Unsheltered_Data_Washington.xlsx: tab "Updated_PITC_for_HUD"
** excelfiles/csvs have line breaks, which breaks stata csv reading.
** merge disability detail back to shelter (HMIS) records.
** append additional counts to updated PITC data (unsheletered/survey)
//
// WashCo sheltered.
import delim using "2023\Data and Tables - Washington\0427_sheltered_Data_Washington_Disability Details.csv", clear varn(1) stringc(1)
gen mh=strpos(disability,"Mental")>0
gen sud=strpos(disability,"Use")>0
gen disphy=strpos(disability,"Physical")>0
gen disdev=strpos(disability,"Developmental")>0
gen health=strpos(disability,"Chronic Health")>0
collapse (max) mh sud disphy disdev health, by(clientid)
tostring mh sud disphy disdev health, replace
for var mh sud disphy disdev health: replace X="Yes" if X=="1" \\ replace X="No" if X=="0"
tempfile tmp 
save `tmp', replace // conditions
import delim using "2023\Data and Tables - Washington\0427_sheltered_Data_Washington_Sheltered_Client.csv", clear  varn(1)
merge 1:1 clientid using `tmp', keep(1 3) keepus(mh sud) 
for var mh sud: replace X="No" if X=="" // assume NO if not in disability HMIS records.
gen id=clientid
gen group_id=hhid
gen hh_type=""
replace hh_type="Adult" if inlist(famtype,"A","Sa")
replace hh_type="Children" if famtype=="Sc"
replace hh_type="Family" if famtype=="AC"
bigtab hh_type famtype
bys hhid: gen listme=_n
egen hh_size=max(listme),by(hhid)
drop listme
gen byte hoh=.
replace hoh=1 if hohrelate=="Self"
replace hoh=0 if inlist(hohrelate,"Member","Child","Spouse")
bigtab hoh hohrelate 
destring age, replace ignore("null")
gen bdate=date(dob,"MDY")
gen ageb=round((date("01/01/2023","MDY") - bdate)/365.25) // fixed ages
replace ageb=age if ageb==. & age<. // prioritize age from birthdate not reported.
drop age 
ren ageb age
gen adult=inrange(age,18,.)|age==. // assume adult if missing age
gen youth=inrange(age,18,24)
gen child=inrange(age,0,17)
egen youth_hh=max(youth),by(group_id) // any youth
egen child_hh=max(child),by(group_id) // any child 
for var adult child: egen famnX=sum(X),by(group_id)
recode age (0/17=1 "Under 18") ///
		   (18/24=2 "18-24") ///
		   (25/34=3 "25-34") ///
		   (35/44=4 "35-44") ///
		   (45/54=5 "45-54") ///
		   (55/64=6 "55-64") ///
		   (65/199=7 "65+"), gen(agecat)
drop age
decode agecat, gen(age)
drop agecat
bigtab age
replace gender="" if !inlist(gender,"Female", "Male", "Transgender", "No Single Gender", "Questioning")
bigtab gender
replace ethnicity="" if strpos(ethnicity,"Hispanic")==0 
replace ethnicity="Hispanic/Latin(a)(o)(x)" if ethnicity=="Hispanic"
replace ethnicity="Non-Hispanic/Non-Latin(a)(o)(x)" if ethnicity=="Non-Hispanic"
bigtab ethnicity
gen race=""
replace race="American Indian, Alaska Native, or Indigenous" if racecombo=="AI/AN/I"
replace race="Asian or Asian American" if racecombo=="Asian"
replace race="Black, African American, or African" if racecombo=="Black"
replace race="Native Hawaiian or Pacific Islander" if racecombo=="NH/PI"
replace race="Multiple" if strpos(racecombo,"Multiple")>0
replace race="White" if racecombo=="White"
bigtab race racecombo
gen status=projtype
gen chronic=chronically_homeless if inlist(chronically_homeless,"Yes","No")
for var vet dv chronic: replace X="Yes" if X=="Y" \\ replace X="No" if X=="N" \\ replace X="" if !inlist(X,"Yes","No")
cap drop vet_hh
foreach v of varlist chronic vet youth child {
	cap drop `v'_hh
	cap gen `v'_temp=(`v'=="Yes")
	cap gen `v'_temp=(`v'==1)
	egen `v'_hh=max(`v'_temp), by(group_id)
	drop `v'_temp
}
gen int county=67
gen int year=2023
ren vet veteran 
gen source="HMIS"
gen parenting_child=(hh_type=="Family"&child_hh==1)
replace parenting_youth="0" if parenting_youth=="No"
replace parenting_youth="1" if parenting_youth=="Yes"
destring parenting_youth, replace force
gen parenting_youth2=(hh_type=="Family"&youth_hh==1&famnadult==0)
gen parenting_youth3=(hh_type=="Family"&youth_hh==1)
bigtab parenting_youth parenting_youth2 parenting_youth3 // not encouraging; I can't replicate the parenting_youth field.
drop parenting_youth* // not keeping until this is sorted out.
// export
** missing hiv status
keep id group_id county year hh_size hh_type ///
	 vet_hh youth_hh chronic_hh child_hh ///
	 hoh gender ethnicity race veteran chronic sud dv mh age ///
	 status source // parenting_youth parenting_child 
export delim using "2023\Data and Tables - Washington\WashCo_PIT_2023_shelter1.csv", replace
//
// WashCo unsheltered.
** part 1 "additional count"
import delim using "2023\Data and Tables - Washington\0427_Unsheltered_Data_Washington_additional count.csv", clear varn(1)
drop if source==""
qui for var *: cap replace X=trim(subinstr(X,"(HUD)","",.)) // remove substring
sort lname fname age // some appear to be related, but can't confirm -- no location data provided.
duplicates drop lname fname dob, force // 1 obs duplicated
gen group_id=hhid
replace group_id=hmisid if group_id==. // assuming single person if no hhid provided
gen bdate=date(dob,"MDY")
gen ageb=round((date("01/01/2023","MDY") - bdate)/365.25) // fixed ages
gen adult=inrange(ageb,18,.)|age==. // assume adult if missing age
gen child=inrange(ageb,0,17)
gen youth=inrange(ageb,18,24)
egen youth_hh=max(youth),by(group_id) // any youth
egen child_hh=max(child),by(group_id) // any child 
egen hh_size=count(hmisid),by(group_id) // total hh size
for var adult child: egen famnX=sum(X),by(group_id)
gen hh_type=""
replace hh_type="Adult" if famnadult>0 & famnchild==0
replace hh_type="Children" if famnadult==0 & famnchild>0
replace hh_type="Family" if famnadult>0 & famnchild>0
tab hh_type, mis
egen agecat=cut(ageb),at(0,18,25,35,45,55,65,199)
lab def a 0 "Under 18" 18 "18-24" 25 "25-34" 35 "35-44" 45 "45-54" 55 "55-64" 65 "65+", replace
label values agecat a
decode agecat, gen(agec)
drop age ageb agecat
ren agec age
replace ethnicity="" if strpos(ethnicity,"Hispanic")==0
tab ethnicity, mis
gen race=""
replace race="American Indian, Alaska Native, or Indigenous" if racecombo=="AIANI"
replace race="Asian or Asian American" if racecombo=="Asian"
replace race="Black, African American, or African" if racecombo=="Black"
replace race="Native Hawaiian or Pacific Islander" if racecombo=="NP/PI"
replace race="Multiple" if strpos(racecombo,"Multiple")>0
replace race="White" if racecombo=="White"
bigtab race racecombo
ren veteranstatus veteran
tab veteran, mis
gen vetn=.
replace vetn=1 if veteran=="Yes"
replace vetn=0 if veteran=="No"
egen vet_hh=max(vetn), by(group_id)
ren chronically_homeless chronic
tab chronic, mis
gen byte chronicn=.
replace chronicn=1 if chronic=="Yes"
replace chronicn=0 if chronic=="No"
egen chronic_hh=max(chronicn), by(group_id)
gen health=doyouhaveachronichealthcondition
gen mh=doyouhaveamentalhealthdisorder_s
gen sud=doyouhaveasubstanceusedisorder_s
gen hiv=doyouhaveaidsoranhivrelatedillne
gen disphy=doyouhaveaphysicaldisability_sur
gen disdev=doyouhaveadevelopmentaldisabilit
gen dv=areyoucurrentlyexperiencinghomel
for var health-dv: assert inlist(X,"Yes","No","")
gen spell=howlonghaveyoubeenhomelessthisti
gen spell3=howmanymonthsdidyoustayinshelter
gen stay3=howmanyseparatetimeshaveyoustaye
gen id=hmisid
gen int county=67
gen int year=2023
gen status="US"
replace source="HMIS" // actual source="Street Outreach" or "CES", but all nomissing HMIS = proximate source.
*cap gen parenting_child=(hh_type=="Family"&child_hh==1)
*cap gen parenting_youth=(hh_type=="Family"&youth_hh==1)
// export
** missing hohrelate
keep id group_id county year hh_size hh_type ///
	 vet_hh youth_hh chronic_hh child_hh ///
	 gender ethnicity race veteran chronic sud dv mh hiv age ///
	 status source // parenting_youth parenting_child 
export delim using "2023\Data and Tables - Washington\WashCo_PIT_2023_unshelter1.csv", replace
** part 2 "additional count"
import delim using "2023\Data and Tables - Washington\0427_Unsheltered_Data_Washington_Updated_PITC_for_HUD.csv", clear varn(1)
qui for var *: cap replace X=trim(subinstr(X,"(HUD)","",.)) // remove substring
gen group_id=household_id
replace group_id=hmisid if hmisid<.
replace group_id=response_id if group_id==.
gen id=response_id
gen bdate=date(dob,"MDY")
gen ageb=round((date("01/01/2023","MDY") - bdate)/365.25) // fixed ages
replace ageb=age if ageb==. & age<.
gen adult=inrange(ageb,18,.)|age==. // assume adult if missing age
gen child=inrange(ageb,0,17)
gen youth=inrange(ageb,18,24)
egen youth_hh=max(youth),by(group_id) // any youth
egen child_hh=max(child),by(group_id) // any child 
egen hh_size=count(id),by(group_id) // total hh size
for var adult child: egen famnX=sum(X),by(group_id)
drop hh_type // wrong coding HH/IND
gen hh_type=""
replace hh_type="Adult" if famnadult>0 & famnchild==0
replace hh_type="Children" if famnadult==0 & famnchild>0
replace hh_type="Family" if famnadult>0 & famnchild>0
tab hh_type, mis
egen agecat=cut(ageb),at(0,18,25,35,45,55,65,199)
replace agecat=0 if age_range=="Under 5"
gen agestub=real(substr(age_range,1,2)) if real(substr(age_range,1,2))<.
egen agecat2=cut(agestub),at(0,18,25,35,45,55,65,199)
replace agecat=agecat2 if agecat==. & agestub<. // add missing data for age when have age interval.
lab def a 0 "Under 18" 18 "18-24" 25 "25-34" 35 "35-44" 45 "45-54" 55 "55-64" 65 "65+", replace
label values agecat a
decode agecat, gen(agec)
drop age ageb agecat agestub agecat2
ren agec age
tab age, mis
drop gender
gen gender=gender_list
replace gender="Transgender" if gender_list=="Female,Transgender"
replace gender="No Single Gender" if gender_list=="NoSingleGender"
replace gender="" if inlist(gender_list,"DataNotCollected","Don'tKnow","Refused")
bigtab gender gender_list
replace ethnicity="" if strpos(ethnicity,"Hispanic")==0
tab ethnicity, mis
drop race
gen race=""
replace race="American Indian, Alaska Native, or Indigenous" if race_combo=="AIANI"
replace race="Asian or Asian American" if race_combo=="Asian"
replace race="Black, African American, or African" if race_combo=="Black"
replace race="Native Hawaiian or Pacific Islander" if race_combo=="NH/PI"
replace race="Multiple" if strpos(race_combo,"Multiple")>0
replace race="White" if race_combo=="White"
bigtab race race_combo
gen veteran=vet_status
gen chronic=usechronically_homeless
gen health=chronichealthcondition
gen mh=mentalhealthdisorder
gen sud=substanceusedisorder
replace sud="Yes" if strpos(sud,"use")>0
gen hiv=aidsoranhivrelatedillness
gen disphy=physicaldisability
gen disdev=developmentaldisability
gen dv=areyoucurrentlyexperiencinghomel
for var veteran-dv: replace X="" if inlist(X,"Data not collected","Don't Know","Refused") \\ assert inlist(X,"Yes","No","")
gen vetn=.
replace vetn=1 if veteran=="Yes"
replace vetn=0 if veteran=="No"
egen vet_hh=max(vetn), by(group_id)
gen byte chronicn=.
replace chronicn=1 if chronic=="Yes"
replace chronicn=0 if chronic=="No"
egen chronic_hh=max(chronicn), by(group_id)
gen spell=howlonghaveyoubeenhomelessthisti
gen spell3=howmanymonthsdidyoustayinshelter
gen stay3=howmanyseparatetimeshaveyoustaye
gen int county=67
gen int year=2023
gen status="US"
gen source="Survey"
*cap gen parenting_child=(hh_type=="Family"&child_hh==1)
*cap gen parenting_youth=(hh_type=="Family"&youth_hh==1)
// export
** missing hohrelate
keep id group_id county year hh_size hh_type ///
	 vet_hh youth_hh chronic_hh child_hh ///
	 gender ethnicity race veteran chronic sud dv mh hiv age ///
	 status source // parenting_youth parenting_child 
export delim using "2023\Data and Tables - Washington\WashCo_PIT_2023_unshelter2.csv", replace

// assemble unified dataset for figures/tables.
import delim using "2023\Data and Tables - Washington\WashCo_PIT_2023_shelter1.csv", clear varn(1)
tostring id group_id, replace
save hrac_pitc23_data.dta, replace
import delim using "2023\Data and Tables - Washington\WashCo_PIT_2023_unshelter1.csv", clear varn(1)
tostring id group_id, replace
append using hrac_pitc23_data.dta
save hrac_pitc23_data.dta, replace
import delim using "2023\Data and Tables - Washington\WashCo_PIT_2023_unshelter2.csv", clear varn(1)
tostring id group_id, replace
append using hrac_pitc23_data.dta
save hrac_pitc23_data.dta, replace
import delim using "2023\Data and Tables - Multnomah\MultCo_PIT_2023.csv", clear varn(1)
tostring id group_id, replace
destring child_hh hh_size, replace ignore("InfHHIND") // R errors in the Multco data.
replace hh_size=hh_size2 if hh_size==. & hh_size2<.
gen int county=51
gen int year=2023
append using hrac_pitc23_data.dta
save hrac_pitc23_data.dta, replace
import delim using "2023\Data and Tables - Clackamas\ClackCo_PIT_2023.csv", clear varn(1)
tostring id group_id, replace
gen source="Survey"
gen int county=5
gen int year=2023
append using hrac_pitc23_data.dta
save hrac_pitc23_data.dta, replace

// cleaning
lab def c 5 "Clackamas" 51 "Multnomah" 67 "Washington", replace
label values county c
ren hh_size hhsize
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
drop hh_type gender age ethnicity race veteran chronic sud hiv dv mh status source
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
*lab var parenting_child "family hh w/child <18?"

// placeholder 2022 data
expand 2, gen(dummy) // dummy data for 2022
replace year=2022 if dummy==1

// create tri-county copy; save
save hrac_pitc23_data.dta, replace
replace county=0 
lab def c 0 "Tri-County", modify
append using hrac_pitc23_data.dta, gen(copy)
save hrac_pitc23_data.dta, replace
*/

/***
 *     ____     ___  ____   ___   ____  ______ 
 *    |    \   /  _]|    \ /   \ |    \|      |
 *    |  D  ) /  [_ |  o  )     ||  D  )      |
 *    |    / |    _]|   _/|  O  ||    /|_|  |_|
 *    |    \ |   [_ |  |  |     ||    \  |  |  
 *    |  .  \|     ||  |  |     ||  .  \ |  |  
 *    |__|\_||_____||__|   \___/ |__|\_| |__|  
 *                                             
 */

// define color schemes
// 1. 3-way 
global c1="forest_green*.9"
global c2="orange*.9"
global c3="eltblue*.9"

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
		symy(*1.75) symx(*.75) r(1)) aspect(1) xsize(4) ysize(4)
graph save fig2.gph, replace
graph export fig2.emf, replace
