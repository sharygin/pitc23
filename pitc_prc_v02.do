// notes
** v01: Washington Co. sheltered is missing HIV status.
** v02: added back health disphy disdev, and fixed multco 2022 race/eth
**		clackamas 2022 sheltered missing health disphy disdev
**		clack, mult 2023 missing health disphy disdev

// working directory
cd "C:\Users\sharygin\pdx\PROJECTS\_current\_pitc"

// prerequisites
foreach p in "tablecol" "bigtab" "xtable" "carryforward" {
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
 *     \____||_____||_____||__|__||__|__|	2022
 *                                       
 */

// initialize 2022 dataset
touch "hrac_pitc23_data_2022.dta", replace
 
// washco sheltered 
** 03.29.2022 - 0630a - 2022 FINAL COMBINED Sheltered PIT.xlsx tab "Tab F - Disability Detail"
import excel using "2022\Washington\03.29.2022 - 0630a - 2022 FINAL COMBINED Sheltered PIT.xlsx", sheet("Tab F - Disability Detail") clear firstrow case(lower)
carryforward clientid100, replace
drop if clientuniqueid100==""
gen uniqueid=clientuniqueid100 
gen mh=strpos(disability,"Mental")>0
gen sud=strpos(disability,"Use")>0
gen disphy=strpos(disability,"Physical")>0
gen disdev=strpos(disability,"Developmental")>0
gen health=strpos(disability,"Chronic Health")>0
collapse (max) mh sud disphy disdev health, by(uniqueid)
tostring mh sud disphy disdev health, replace
for var mh sud disphy disdev health: replace X="Yes" if X=="1" \\ replace X="No" if X=="0"
tempfile tmp 
save `tmp', replace // conditions
** 03.29.2022 - 0630a - 2022 FINAL COMBINED Sheltered PIT.xlsx tab "Tab E - Client Detail"
import excel using "2022\Washington\03.29.2022 - 0630a - 2022 FINAL COMBINED Sheltered PIT.xlsx", sheet("Tab E - Client Detail") clear firstrow case(lower)
drop if uniqueid==""
bys uniqueid: gen listme=_n
keep if listme==1 // keep 1 obs per person.
merge 1:1 uniqueid using `tmp', keep(1 3) keepus(mh sud health disphy disdev) 
for var mh sud health disphy disdev: replace X="No" if _merge==1 // assume no mh/sud if not in disability detail dataset
gen id=uniqueid
gen group_id=hhgroup349
unique id
assert `r(N)'==`r(unique)'
egen hhsize=count(clientid573),by(group_id) // counts nonmissing numeric variable; uniqueid is alphanumeric
recode age (0/17=1 "Under 18") ///
		   (18/24=2 "18-24") ///
		   (25/34=3 "25-34") ///
		   (35/44=4 "35-44") ///
		   (45/54=5 "45-54") ///
		   (55/64=6 "55-64") ///
		   (65/199=7 "65+"), gen(agecat)
decode agecat, gen(agerc)
gen adult=inrange(age,18,.)|age==.|agecat>=2 // assume adult if missing age
gen youth=inrange(age,18,24)|agecat==2
gen child=inrange(age,0,17)|agecat==1
egen youth_hh=max(youth),by(group_id) // any youth
egen child_hh=max(child),by(group_id) // any child 
gen hoh=(hohrelate=="Self")
gen hh_typerc=""
replace hh_typerc="Adult" if inlist(famtype,"A","Sa","SyA","yA")
replace hh_typerc="Children" if famtype=="Sc"
replace hh_typerc="Family" if inlist(famtype,"AC","yAC")
bigtab hh_typerc famtype
gen genderrc=gender if inlist(gender,"Female", "Male", "Transgender", "No Single Gender", "Questioning")
bigtab genderrc gender
gen hispanrc=""
replace hispanrc="Hispanic/Latin(a)(o)(x)" if ethnicity=="Hispanic"
replace hispanrc="Non-Hispanic/Non-Latin(a)(o)(x)" if ethnicity=="Non-Hispanic"
bigtab hispanrc ethnicity
gen racerc=""
replace racerc="American Indian, Alaska Native, or Indigenous" if primaryrace=="AI/AN/I"
replace racerc="Asian or Asian American" if primaryrace=="Asian"
replace racerc="Black, African American, or African" if primaryrace=="Black"
replace racerc="Native Hawaiian or Pacific Islander" if primaryrace=="NH/PI"
replace racerc="White" if primaryrace=="White"
replace racerc="Multiple" if inlist(ndrace,"Black","White","AI/AN/I","NH/PI","Asian") & racerc!="" & primaryrace!=ndrace
bigtab racerc primaryrace ndrace
gen veteranrc=""
replace veteranrc="No" if vet=="N"
replace veteranrc="Yes" if vet=="Y"
gen dvrc=""
replace dvrc="No" if dvflee=="N"
replace dvrc="Yes" if dvflee=="Y"
gen chronicrc=""
replace chronicrc="Yes" if ch=="X"
foreach v of varlist veteranrc chronicrc {
	gen `v'n=1 if `v'=="Yes" // don't assign 0 if missing, but unknown
	egen `v'_hh=max(`v'n), by(group_id)
	drop `v'n
}
gen status=projtype
gen source="HMIS"
** missing hiv status; chronic missing "no"; assume no disability if not in disability supplement.
keep id group_id hhsize hh_typerc hoh ///
	 genderrc hispanrc racerc veteranrc chronicrc sud dvrc mh agerc /// //hiv
	 veteranrc_hh youth_hh chronicrc_hh child_hh ///
	 status source health disphy disdev // parenting_youth parenting_child 
for any "hh_type" "gender" "race" "hispan" "veteran" "dv" "chronic" "age": ren Xrc X \\ cap ren Xrc_hh X_hh
ren veteran_hh vet_hh
gen byte county=67
gen int year=2022
tostring id group_id, replace
append using "hrac_pitc23_data_2022.dta"
save "hrac_pitc23_data_2022.dta", replace

// wash unsheltered
import excel using "2022\Washington\Washington_unsheltered2022.xlsx", clear firstrow case(lower)
gen id=response_id
gen group_id=household_id
gen hhsize=number_in_household
recode age (0/17=1 "Under 18") ///
		   (18/24=2 "18-24") ///
		   (25/34=3 "25-34") ///
		   (35/44=4 "35-44") ///
		   (45/54=5 "45-54") ///
		   (55/64=6 "55-64") ///
		   (65/199=7 "65+"), gen(agecat)
replace agecat=2 if age_range=="18-24"
replace agecat=3 if age_range=="25-34"
replace agecat=4 if age_range=="35-44"
replace agecat=5 if age_range=="45-54"
decode agecat, gen(agerc)
gen adult=inrange(age,18,.)|age==.|agecat>=2 // assume adult if missing age
gen youth=inrange(age,18,24)|agecat==2
gen child=inrange(age,0,17)|agecat==1
egen youth_hh=max(youth),by(group_id) // any youth
egen child_hh=max(child),by(group_id) // any child 
gen byte hoh=1 if hh_type=="IND" // assume hoh of indiv not in hhd.
replace hoh=1 if hh_type=="HH" & household_entry_number==1 // assume hoh if first respondent in hhd
replace hoh=0 if hh_type=="HH" & household_entry_number>1 
gen hh_typerc=""
replace hh_typerc="Adult" if household_type=="NoChildren" | (hh_type=="IND" & agecat>=2)
replace hh_typerc="Children" if hh_type=="IND" & agecat==1 // hh consists of children only.
replace hh_typerc="Family" if household_type=="Children" // this is not documented in the dataset.
bigtab hh_typerc hh_type household_type // hh_type is poorly specified in this dataset; eg why 1-person HH not coded IND?
gen parenting_youth=parenting_youth_household
gen genderrc=gender_name if inlist(gender_name,"Female", "Male", "Transgender", "No Single Gender", "Questioning")
bigtab genderrc gender_name
gen hispanrc="Non-Hispanic/Non-Latin(a)(o)(x)" if ethnicity=="No"
replace hispanrc="Hispanic/Latin(a)(o)(x)" if ethnicity=="No"
bigtab hispanrc ethnicity
foreach r in "aminaknative" "asian" "blackafamerican" "nativehiotherpi" "white" "other" {
	gen race_`r'_dummy=0 if race_`r'=="No"
	replace race_`r'_dummy=1 if race_`r'=="Yes"
}
egen race_chk=rowtotal(race_*_dummy)
gen racerc=""
replace racerc="American Indian, Alaska Native, or Indigenous" if race_aminaknative=="Yes" & race_chk==1
replace racerc="Asian or Asian American" if race_asian=="Yes" & race_chk==1
replace racerc="Black, African American, or African" if race_blackafamerican=="Yes" & race_chk==1
replace racerc="Native Hawaiian or Pacific Islander" if race_nativehiotherpi=="Yes" & race_chk==1
replace racerc="White" if race_white=="Yes" & race_chk==1
replace racerc="Multiple" if race_chk>1 & race_chk<.
replace racerc="Other" if race_other=="Yes" & racerc==""
bigtab racerc race_chk
gen veteranrc=vet_status if inlist(vet_status,"Yes","No")
gen chronicrc=chronically_homeless if inlist(chronically_homeless,"Yes","No")
gen veterann=1 if vet_status=="Yes"
replace veterann=0 if vet_status=="No"
egen veteranrc_hh=max(veterann),by(group_id) // any veteran
gen chronicn=1 if chronicrc=="Yes"
replace chronicn=0 if chronicrc=="No"
egen chronicrc_hh=max(chronicn),by(group_id) // any chro
gen sud="Yes" if strpos(doyouhaveasubstanceusediso,"use")>0
replace sud="No" if doyouhaveasubstanceusediso=="No"
gen health=doyouhaveachronichealthcon if inlist(doyouhaveachronichealthcon,"Yes","No")
gen mh=doyouhaveamentalhealthdiso if inlist(doyouhaveamentalhealthdiso,"Yes","No")
gen disphy=doyouhaveaphysicaldisabilit if inlist(doyouhaveaphysicaldisabilit,"Yes","No")
gen disdev=doyouhaveadevelopmentaldisa if inlist(doyouhaveadevelopmentaldisa,"Yes","No")
gen dvrc=areyoucurrentlyexperiencingh if inlist(areyoucurrentlyexperiencingh,"Yes","No")
gen status="US"
gen source="Survey"
** missing hiv status; chronic missing "no"; assume no disability if not in disability supplement.
keep id group_id hhsize hh_typerc hoh ///
	 genderrc hispanrc racerc veteranrc chronicrc sud dvrc mh agerc /// //hiv
	 veteranrc_hh chronicrc_hh youth_hh child_hh ///
	 status source health disphy disdev // parenting_youth parenting_child 
for any "hh_type" "gender" "race" "hispan" "veteran" "dv" "chronic" "age": ren Xrc X \\ cap ren Xrc_hh X_hh
ren veteran_hh vet_hh
gen byte county=67
gen int year=2022
tostring id group_id, replace
append using "hrac_pitc23_data_2022.dta"
save "hrac_pitc23_data_2022.dta", replace

// multnomah (total N=5228)
** disability types by ID
import excel using "2022\Multnomah\PIT Count_Local Data_Final Corrected.xlsx", clear firstrow case(lower)
preserve
gen id=pit_uid
keep id disabilitytype
gen hiv=disabilitytype=="HIV/AIDS"
gen health=disabilitytype=="Chronic Health Condition"
gen mh=strpos(disabilitytype,"Mental")>0
gen sud=strpos(disabilitytype,"Use")>0
gen disphy=disabilitytype=="Physical Disability"
gen disdev=disabilitytype=="Developmental Disability"
collapse (max) hiv-disdev, by(id)
for var hiv-disdev: tostring X, replace \\ replace X="Yes" if X=="1" \\ replace X="No" if X=="0"
tempfile tmp1
save `tmp1', replace
** ethnicity by ID
restore
drop if inlist(raceeth,"Non-Hispanic White","BIPOC") // these are created, duplicate obs.
gen id=pit_uid
gen hispanrc="Hispanic/Latin(a)(o)(x)" if strpos(raceeth,"spanic")>0 & strpos(raceeth,"No")==0 
replace hispanrc="Non-Hispanic/Non-Latin(a)(o)(x)" if hispanrc=="" & raceeth!="Race/ethnicity unreported" // only missing if skipped question.
preserve
contract id hispanrc
bys id: gen listme=_n
egen listme2=max(listme),by(id)
drop if listme2>1 & inlist(hispanrc,"","Non-Hispanic/Non-Latin(a)(o)(x)") // if has a positive result, drop other results.
tempfile tmp2
save `tmp2', replace
** race by ID
restore
gen racerc=""
replace racerc="American Indian, Alaska Native, or Indigenous" if strpos(raceeth,"Indian")>0
replace racerc="Asian or Asian American" if raceeth=="Asian or Asian American"
replace racerc="Black, African American, or African" if inlist(raceeth,"African","Black, African American or African")
replace racerc="Native Hawaiian or Pacific Islander" if raceeth=="Native Hawaiian or Pacific Islander"
replace racerc="White" if inlist(raceeth,"White","Slavic","Middle Eastern")|raceeth=="Non-Hispanic White"
replace racerc="Multiple" if raceeth=="MultiRacial"
contract id racerc
drop _freq
gen chkr1=1 if racerc!=""
egen chkr=sum(chkr1), by(id)
replace racerc="Multiple" if chkr>1 & chkr<.
contract id racerc
bys id: gen listme=_n
egen listme2=max(listme),by(id)
drop if listme2>1 & racerc=="" // has a nonmissing race; drop missing.
tempfile tmp3
save `tmp3', replace
** deduplicated demographic file -- take modal nonmissing string response for deduplication
import excel using "2022\Multnomah\PIT Count_Local Data_Final Corrected.xlsx", clear firstrow case(lower)
gen id=pit_uid
gen group_id=hhid
gen hoh=0 if !inlist(relationshiptohoh,"","Missing")
replace hoh=1 if relationshiptohoh=="Self"
bigtab hoh relationshiptohoh
gen hh_typerc=""
replace hh_typerc="Adult" if inlist(hhtype,"A","Sa","SyA","yA")
replace hh_typerc="Children" if hhtype=="Sc"
replace hh_typerc="Family" if inlist(hhtype,"AC","yAC")
bigtab hh_typerc hhtype
gen genderrc=gender if inlist(gender,"Female", "Male", "Transgender", "No Single Gender", "Questioning")
replace genderrc="No Single Gender" if gender=="Not Singular"
bigtab genderrc gender
replace vet=proper(vet)
gen veteranrc=vet if inlist(vet,"Yes","No")
replace vethousehold=proper(vethousehold)
gen vet_hh=vethousehold if inlist(vethousehold,"Yes","No")
gen dvrc=dvhomeless if inlist(dvhomeless,"Yes","No")
gen chronicrc=""
replace chronicrc="No" if chronicallyunhoused=="Not CH"
replace chronicrc="Yes" if chronicallyunhoused=="CH_"
foreach v of varlist veteranrc chronicrc {
	gen `v'n=1 if `v'=="Yes" // don't assign 0 if missing, but unknown
	egen `v'_hh=max(`v'n), by(group_id)
	drop `v'n
}
gen status=livingsituation
replace status="US" if status=="Unsheltered"
** missing source. repeated records, processed race/eth and disabilities
keep id group_id hh_typerc hoh age ///
	 genderrc veteranrc chronicrc dvrc age /// 
	 status // source parenting_youth parenting_child + hispanrc racerc 
bys id: gen listme=_n
gsort id listme
foreach v of varlist age status hoh hh_typerc genderrc veteranrc chronicrc dvrc {
	cap egen m_`v'=mode(`v') if `v'!="", by(id) // strings 
	cap egen m_`v'=mode(`v') if `v'<., by(id) // numeric
	gsort id listme
	by id: carryforward m_`v', replace // extend nonmissings down
	gsort id -listme
	by id: carryforward m_`v', replace // extend first nonmissing up
	drop `v'
	ren m_`v' `v'
}
keep if listme==1 // now
drop listme
merge 1:1 id using `tmp1', assert(1 3) nogen keepus(hiv sud mh health disphy disdev) // add back hiv sud mh and health conditions
merge 1:1 id using `tmp2', assert(1 3) nogen keepus(hispanrc) // add back hispanic
merge 1:1 id using `tmp3', assert(1 3) nogen keepus(racerc) // add back race
unique id
assert `r(N)'==`r(unique)'
egen hhsize=count(id),by(group_id) // generate hhsize
// regenerate chronichh, vethh, childhh, youthh
recode age (0/17=1 "Under 18") ///
		   (18/24=2 "18-24") ///
		   (25/34=3 "25-34") ///
		   (35/44=4 "35-44") ///
		   (45/54=5 "45-54") ///
		   (55/64=6 "55-64") ///
		   (65/199=7 "65+"), gen(agecat)
decode agecat, gen(agerc)
drop age
for any "hh_type" "gender" "race" "hispan" "veteran" "dv" "chronic" "age": ren Xrc X 
gen adult=agecat>=2 // assume adult if missing age
gen youth=agecat==2
gen child=agecat==1
egen youth_hh=max(youth),by(group_id) // any youth
egen child_hh=max(child),by(group_id) // any child 
gen veterann=1 if veteran=="Yes"
replace veterann=0 if veteran=="No"
egen vet_hh=max(veterann),by(group_id) // any veteran
gen chronicn=1 if chronic=="Yes"
replace chronicn=0 if chronic=="No"
egen chronic_hh=max(chronicn),by(group_id) // any chronic
keep id group_id hh_type hoh hhsize ///
	 gender hispan race veteran chronic dv age /// 
	 vet_hh chronic_hh youth_hh child_hh ///
	 hiv mh sud status health disphy disdev // source parenting_youth parenting_child 
gen byte county=51
gen int year=2022
tostring id group_id, replace
append using "hrac_pitc23_data_2022.dta"
save "hrac_pitc23_data_2022.dta", replace

// clackamas county
** sheltered
import excel using "2022\Clackamas\2022 Clackamas Sheltered PIT Combined for PSU_copy.xlsx", sheet("2022 Sheltered PIT") clear firstrow case(lower)
carryforward hhgroup188, gen(group_id)
gen id=clientid
order id group_id
unique id
assert `r(N)'==`r(unique)'
egen hhsize=count(id),by(group_id)
destring age, replace ignore("null")
recode age (0/17=1 "Under 18") ///
		   (18/24=2 "18-24") ///
		   (25/34=3 "25-34") ///
		   (35/44=4 "35-44") ///
		   (45/54=5 "45-54") ///
		   (55/64=6 "55-64") ///
		   (65/199=7 "65+"), gen(agecat)
decode agecat, gen(agerc)
gen adult=agecat>=2 // assume adult if missing age
gen youth=agecat==2
gen child=agecat==1
egen youth_hh=max(youth),by(group_id) // any youth
egen child_hh=max(child),by(group_id) // any child 
gen hoh=0 if !inlist(hohrelate,"","Missing")
replace hoh=1 if hohrelate=="Self"
bigtab hoh hohrelate
gen hh_typerc=""
replace hh_typerc="Adult" if inlist(famtype,"A","Sa","SyA","yA")
replace hh_typerc="Children" if famtype=="Sc"
replace hh_typerc="Family" if inlist(famtype,"AC","yAC")
bigtab hh_typerc famtype
gen genderrc=gender if inlist(gender,"Female", "Male", "Transgender", "No Single Gender", "Questioning")
replace genderrc="No Single Gender" if gender=="Not Singular"
bigtab genderrc gender
gen hispanrc=""
replace hispanrc="Hispanic/Latin(a)(o)(x)" if strpos(ethnicity,"Hispanic")>0
replace hispanrc="Non-Hispanic/Non-Latin(a)(o)(x)" if strpos(ethnicity,"Non-")>0
bigtab hispanrc ethnicity
gen racerc=""
replace racerc="American Indian, Alaska Native, or Indigenous" if primaryrace=="AI/AN/I"
replace racerc="Asian or Asian American" if primaryrace=="Asian"
replace racerc="Black, African American, or African" if primaryrace=="Black"
replace racerc="Native Hawaiian or Pacific Islander" if primaryrace=="NH/PI"
replace racerc="White" if primaryrace=="White"
replace racerc="Multiple" if inlist(ndrace,"Black","White","AI/AN/I","NH/PI","Asian") & racerc!="" & primaryrace!=ndrace
bigtab racerc primaryrace ndrace
gen veteranrc=""
replace veteranrc="No" if vet=="N"
replace veteranrc="Yes" if vet=="Y"
gen dvrc=""
replace dvrc="No" if dvflee=="N"
replace dvrc="Yes" if dvflee=="Y"
gen chronicrc=""
replace chronicrc="No" if chronichomeless=="N"
replace chronicrc="Yes" if chronichomeless=="Y"
gen sud=""
replace sud="No" if disabsubstance=="N"
replace sud="Yes" if disabsubstance=="Y"
gen hiv=""
replace hiv="No" if hivaids=="N"
replace hiv="Yes" if hivaids=="Y"
gen mh=""
replace mh="No" if mentalhealthdisorder=="N"
replace mh="Yes" if mentalhealthdisorder=="Y"
gen veterann=1 if veteranrc=="Yes"
replace veterann=0 if veteranrc=="No"
egen veteranrc_hh=max(veterann),by(group_id) // any veteran
gen chronicn=1 if chronicrc=="Yes"
replace chronicn=0 if chronicrc=="No"
egen chronicrc_hh=max(chronicn),by(group_id) // any chro
gen status=projecttype
gen source="HMIS"
for any "health" "disphy" "disdev": cap gen X="" // missing, have only 'disabyn'
keep id group_id hhsize hh_typerc hoh ///
	 genderrc hispanrc racerc veteranrc chronicrc sud dvrc mh hiv agerc /// 
	 veteranrc_hh chronicrc_hh youth_hh child_hh ///
	 status source health disphy disdev // parenting_youth parenting_child 
for any "hh_type" "gender" "race" "hispan" "veteran" "dv" "chronic" "age": ren Xrc X \\ cap ren Xrc_hh X_hh
ren veteran_hh vet_hh
gen byte county=5
gen int year=2022
tostring id group_id, replace
append using "hrac_pitc23_data_2022.dta"
save "hrac_pitc23_data_2022.dta", replace

// clackamas unsheltered
** a tricky one. this has the household members with responses prefixed "hhm1_" and "hhm2_" with different Q numbers.
** note that hh members not asked hispanic. DV flee is only asked for DV=yes.
** approach is to duplicate records for hh members, then rename to be consistent with main hh reporters, then append.
** health = q13_chronic + hhmX_q12_chronic
** disphy = q13_phydisab + hhmX_q12_phydisab
** disdev = q13_devdisab + hhmX_q12_devdisab
import excel using "2022\Clackamas\CLACKAMAS PIT 2022 Survey Data_FINAL_4-16-22_copy.xlsx", clear firstrow case(lower)
tostring id, replace
gen group_id=id
for var *age*: destring X, replace ignore("Missing") 
gen hh_type=""
replace hh_type="Adult" if inrange(age,18,199) & !inrange(hhm1_age,0,17) & !inrange(hhm2_age,0,17)
replace hh_type="Family" if (inrange(age,18,199) & (inrange(hhm1_age,0,17) | inrange(hhm2_age,0,17)) ) ///
						| (inrange(age,0,17) & (inrange(hhm1_age,18,199) | inrange(hhm2_age,18,199))) 
replace hh_type="Child" if inrange(age,0,17) & !inrange(hhm1_age,18,199) & !inrange(hhm2_age,18,199)
gen child_hh=(inrange(age,0,17)|inrange(hhm1_age,0,17)|inrange(hhm2_age,0,17))
gen youth_hh=(inrange(age,18,24)|inrange(hhm1_age,18,24)|inrange(hhm2_age,18,24))
tab hh_type, mis
tempfile tmp1 tmp2
preserve
keep group_id hhm1*
gen id=group_id+"a"
ren hhm1_* *
ren q5* x7*
ren q8* x12*
ren q12* x13*
ren q11* x10*
gen byte hoh=0
keep id group_id age gender* x7* x12* x13* x10*
tostring gender* x*, replace
qui for var gender* x7* x12* x13* x10*: replace X="" if X=="Missing"
drop if age==. 
save `tmp1'
restore, preserve
keep group_id hhm2*
ren hhm2_* *
gen id=group_id+"b"
ren q5* x7*
ren q8* x12*
ren q12* x13*
ren q11* x10*
gen byte hoh=0
keep id group_id age gender* x7* x12* x13* x10*
tostring gender* x*, replace
qui for var gender* x7* x12* x13* x10*: replace X="" if X=="Missing"
drop if age==. 
save `tmp2'
restore
keep id group_id hh_type age gender* q7* q12* q13* q10* 
rename q* x*
tostring gender* x*, replace
gen byte hoh=1
append using `tmp1', gen(hhm1)
append using `tmp2', gen(hhm2)
replace hoh=0 if hoh==.
gen genderrc=""
replace genderrc="Male" if gender_male=="Selected" & genderrc==""
replace genderrc="Female" if gender_female=="Selected" & genderrc==""
replace genderrc="Transgender" if gender_trans=="Selected" & genderrc==""
replace genderrc="No Single Gender" if gender_notsingular=="Selected" & genderrc==""
replace genderrc="Questioning" if gender_question=="Selected" & genderrc==""
gen hispanrc="Non-Hispanic/Non-Latin(a)(o)(x)" if x7_hispanic=="Not Selected"
replace hispanrc="Hispanic/Latin(a)(o)(x)" if x7_hispanic=="Selected"
gen black=(x7_african=="Selected"|x7_black=="Selected")
replace black=. if black==0 & (x7_african=="Missing"|x7_black=="Missing")
gen white=(x7_middleeastern=="Selected"|x7_slavic=="Selected"|x7_white=="Selected")
replace white=. if white==0 & (x7_middleeastern=="Missing"|x7_slavic=="Missing"|x7_white=="Missing")
gen asian=(x7_asian=="Selected")
replace asian=. if asian==0 & x7_asian=="Missing"
gen nhpi=x7_nativehawaiian=="Selected"
replace nhpi=. if nhpi==0 & x7_nativehawaiian=="Missing"
gen aian=x7_americanindian=="Selected"
replace aian=. if aian==0 & x7_americanindian=="Missing"
foreach r in "asian" "aian" "black" "nhpi" "white" {
	gen race_`r'_dummy=0 if `r'==0
	replace race_`r'_dummy=1 if `r'==1
}
egen race_chk=rowtotal(race_*_dummy)
gen racerc=""
replace racerc="American Indian, Alaska Native, or Indigenous" if aian==1 & race_chk==1
replace racerc="Asian or Asian American" if asian==1 & race_chk==1
replace racerc="Black, African American, or African" if black==1 & race_chk==1
replace racerc="Native Hawaiian or Pacific Islander" if nhpi==1 & race_chk==1
replace racerc="White" if white==1 & race_chk==1
replace racerc="Multiple" if race_chk>1 & race_chk<.
bigtab racerc race_chk 
gen dvrc=x10a_dvhomeless if inlist(x10a_dvhomeless,"Yes","No")
gen veteranrc=x12_vet if inlist(x12_vet,"Yes","No")
gen chronicrc=""
gen sud="Yes" if x13_alcohol=="Selected"|x13_drug=="Selected"
replace sud="No" if x13_alcohol=="Not Selected"&x13_drug=="Not Selected"
gen hiv="Yes" if x13_hivaids=="Selected"
replace hiv="No" if x13_hivaids=="Not Selected"
gen mh="Yes" if x13_mental=="Selected"
replace mh="No" if x13_mental=="Not Selected"
gen health="Yes" if x13_chronic=="Selected"
replace health="No" if x13_chronic=="Not Selected"
gen disphy="Yes" if x13_phydisab=="Selected"
replace disphy="No" if x13_phydisab=="Not Selected"
gen disdev="Yes" if x13_devdisab=="Selected"
replace disdev="No" if x13_devdisab=="Not Selected"
unique id
assert `r(N)'==`r(unique)'
gen count=1
egen hhsize=count(count),by(group_id)
destring age, replace ignore("null")
recode age (0/17=1 "Under 18") ///
		   (18/24=2 "18-24") ///
		   (25/34=3 "25-34") ///
		   (35/44=4 "35-44") ///
		   (45/54=5 "45-54") ///
		   (55/64=6 "55-64") ///
		   (65/199=7 "65+"), gen(agecat)
decode agecat, gen(agerc)
gen adult=agecat>=2 // assume adult if missing age
gen youth=agecat==2
gen child=agecat==1
egen youth_hh=max(youth),by(group_id) // any youth
egen child_hh=max(child),by(group_id) // any child 
sort group_id id
by group_id: carryforward hh_type, replace
** missing chronic, hispanic for non-hoh, hiv always no.
keep id group_id hoh hh_type ///
	genderrc veteranrc racerc hispanrc dvrc sud hiv mh ///
	youth_hh child_hh hhsize health disphy disdev
for any "gender" "veteran" "race" "hispan" "dv": ren Xrc X
gen status="US"
gen source="Survey"
gen byte county=5
gen int year=2022
append using "hrac_pitc23_data_2022.dta"
save "hrac_pitc23_data_2022.dta", replace


// group order/chk/label
order county year id group_id hhsize hoh hh_type ///
		hh_type child_hh youth_hh vet_hh chronic_hh ///
		hoh age gender hispan race veteran ///
		chronic sud dv hiv mh health disphy disdev status source 
// cleaning
lab def c 5 "Clackamas" 51 "Multnomah" 67 "Washington", replace
label values county c
lab def f 1 "Adult" 2 "Family" 3 "Children"
encode hh_type, gen(hhtype) label(f) noextend
lab def g 1 "Male" 2 "Female" 3 "No Single Gender" 4 "Questioning" 5 "Transgender", replace
encode gender, gen(genderrc) label(g) noextend
lab def h 0 "Non-Hispanic/Non-Latin(a)(o)(x)" 1 "Hispanic/Latin(a)(o)(x)", replace
encode hispan, gen(hispanrc) label(h) noextend
lab def r 1 "White" 2 "Black, African American, or African" 3 "American Indian, Alaska Native, or Indigenous" ///
	4 "Asian or Asian American" 5 "Native Hawaiian or Pacific Islander" 6 "Multiple", replace
encode race, gen(racerc) label(r) noextend
lab def v 0 "No" 1 "Yes", replace
for var veteran chronic sud hiv dv mh health disphy disdev: encode X, gen(Xrc) label(v) noextend
destring *_hh, replace ignore("Inf")
lab def a 1 "Under 18" 2 "18-24" 3 "25-34" 4 "35-44" 5 "45-54" 6 "55-64" 7 "65+", replace
encode age, gen(agecat) label(a) noextend
foreach v in "ES Emergency shelter" "TH Transitional housing" "US Unsheltered" {
	tokenize "`v'"
	replace status=trim("`2' `3'") if status=="`1'"
}
lab def s 1 "Unsheltered" 2 "Emergency shelter" 3 "Transitional housing", replace
encode status, gen(statusrc) label(s) noextend
gen sourcerc=source
drop hh_type gender age hispan race veteran chronic sud hiv dv mh health disphy disdev status source 
rename *rc *

// labels
lab var id "PIT uid"
lab var group_id "HHID"
lab var hhtype "adult/child/family"
lab var hhsize "N in HH"
lab var hoh "HH head?"
lab var agecat "ages <18/18-24/25-34/35-44/45-49/55-64/65+"
lab var gender "gender f/m/n/q/t"
lab var veteran "veteran?"
lab var chronic "chronic homeless?"
lab var mh "mental health disorder?"
lab var sud "substance use disorder?"
lab var hiv "AIDS or HIV?"
lab var dv "victim of DV?"
lab var health "chronic health condition?"
lab var disphy "physical diability?"
lab var disdev "development disability?"
lab var source "HMIS or survey"
lab var status "current status US/TH/ES"
lab var hispan "Hispanic/Latina/o/x?"
lab var race "race w/n/b/a/p/m/."
lab var vet_hh "veteran in hh?"
lab var youth_hh "youth age<25 in hh?"
lab var child_hh "child age<18 in hh?"
lab var chronic_hh "chronic homeless person in hh?"
*lab var parenting_child "family hh w/child <18?"
lab var county "county/geo FIPS code"
cap drop hh_size2
lab var year "PITC year"

// save
notes drop _all
compress
save "hrac_pitc23_data_2022.dta", replace
		
/***
 *        __  _        ___   ____  ____  
 *       /  ]| |      /  _] /    ||    \ 
 *      /  / | |     /  [_ |  o  ||  _  |
 *     /  /  | |___ |    _]|     ||  |  |
 *    /   \_ |     ||   [_ |  _  ||  |  |
 *    \     ||     ||     ||  |  ||  |  |
 *     \____||_____||_____||__|__||__|__|	2023
 *                                       
 */

// initialize dataset
touch "hrac_pitc23_data_2023.dta", replace
 
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
merge 1:1 clientid using `tmp', keep(1 3) keepus(mh sud health disphy disdev) 
for var mh sud health disphy disdev: replace X="No" if X=="" // assume NO if not in disability HMIS records.
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
ren vet veteran 
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
keep id group_id hh_size hh_type ///
	 vet_hh youth_hh chronic_hh child_hh ///
	 hoh gender ethnicity race veteran chronic sud dv mh age ///
	 health disphy disdev status // parenting_youth parenting_child 
gen source="HMIS"
gen int year=2023
gen byte county=67
tostring id group_id, replace
append using "hrac_pitc23_data_2023.dta"
save "hrac_pitc23_data_2023.dta", replace

//
// WashCo unsheltered. part 1 "additional count"
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
	 health disphy disdev status source // parenting_youth parenting_child 
tostring id group_id, replace
append using "hrac_pitc23_data_2023.dta"
save "hrac_pitc23_data_2023.dta", replace

//
// washco unsheltered ** part 2 "additional count"
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
// export
** missing hohrelate
keep id group_id hh_size hh_type ///
	 vet_hh youth_hh chronic_hh child_hh ///
	 gender ethnicity race veteran chronic sud dv mh hiv age health disphy disdev
gen int county=67
gen int year=2023
gen status="US"
gen source="Survey"
tostring id group_id, replace
append using "hrac_pitc23_data_2023.dta"
save "hrac_pitc23_data_2023.dta", replace

// multnomah
import delim using "2023\Data and Tables - Multnomah\MultCo_PIT_2023.csv", clear varn(1)
tostring id group_id, replace
destring child_hh hh_size, replace ignore("InfHHIND") // R errors in the Multco data.
replace hh_size=hh_size2 if hh_size==. & hh_size2<.
gen int county=51
gen int year=2023
append using  "hrac_pitc23_data_2023.dta"
save  "hrac_pitc23_data_2023.dta", replace

// clackamas
import delim using "2023\Data and Tables - Clackamas\ClackCo_PIT_2023.csv", clear varn(1)
tostring id group_id, replace
gen source="Survey"
gen int county=5
gen int year=2023
append using  "hrac_pitc23_data_2023.dta"
save  "hrac_pitc23_data_2023.dta", replace

// cleaning
lab def c 5 "Clackamas" 51 "Multnomah" 67 "Washington", replace
label values county c
ren hh_size hhsize
lab def f 1 "Adult" 2 "Family" 3 "Children"
encode hh_type, gen(hhtype) label(f) noextend
lab def g 1 "Male" 2 "Female" 3 "No Single Gender" 4 "Questioning" 5 "Transgender", replace
encode gender, gen(genderrc) label(g) noextend
replace ethnicity="Hispanic/Latin(a)(o)(x)" if ethnicity=="Hispanic or Latin(a)(o)(x)"
lab def h 0 "Non-Hispanic/Non-Latin(a)(o)(x)" 1 "Hispanic/Latin(a)(o)(x)", replace
encode ethnicity, gen(hispanrc) label(h) noextend
lab def r 1 "White" 2 "Black, African American, or African" 3 "American Indian, Alaska Native, or Indigenous" ///
	4 "Asian or Asian American" 5 "Native Hawaiian or Pacific Islander" 6 "Multiple", replace
encode race, gen(racerc) label(r) noextend
lab def v 0 "No" 1 "Yes", replace
for var veteran chronic sud hiv dv mh health disphy disdev: encode X, gen(Xrc) label(v) noextend
destring *_hh, replace ignore("Inf")
lab def a 1 "Under 18" 2 "18-24" 3 "25-34" 4 "35-44" 5 "45-54" 6 "55-64" 7 "65+", replace
encode age, gen(agecat) label(a) noextend
foreach v in "ES Emergency shelter" "TH Transitional housing" "US Unsheltered" {
	tokenize "`v'"
	replace status=trim("`2' `3'") if status=="`1'"
}
lab def s 1 "Unsheltered" 2 "Emergency shelter" 3 "Transitional housing", replace
encode status, gen(statusrc) label(s) noextend
gen sourcerc=source
drop hh_type gender age ethnicity race veteran chronic sud hiv dv mh health disphy disdev status source 
rename *rc *

// labels
lab var id "PIT uid"
lab var group_id "HHID"
lab var hhtype "adult/child/family"
lab var hhsize "N in HH"
lab var hoh "HH head?"
lab var agecat "ages <18/18-24/25-34/35-44/45-49/55-64/65+"
lab var gender "gender f/m/n/q/t"
lab var veteran "veteran?"
lab var chronic "chronic homeless?"
lab var mh "mental health disorder?"
lab var sud "substance use disorder?"
lab var hiv "AIDS or HIV?"
lab var dv "victim of DV?"
lab var health "chronic health condition?"
lab var disphy "physical diability?"
lab var disdev "development disability?"
lab var source "HMIS or survey"
lab var status "current status US/TH/ES"
lab var hispan "Hispanic/Latinaox?"
lab var race "race w/n/b/a/p/m/."
lab var vet_hh "veteran in hh?"
lab var youth_hh "youth age<25 in hh?"
lab var child_hh "child age<18 in hh?"
lab var chronic_hh "chronic homeless person in hh?"
lab var parenting_child "family hh w/child <18?"
lab var county "county/geo FIPS code"
cap drop hh_size2
lab var year "PITC year"

// export
notes drop _all
compress
save  "hrac_pitc23_data_2023.dta", replace

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

// combined dataset
use "hrac_pitc23_data_2023.dta", clear
append using "hrac_pitc23_data_2022.dta"
replace county=0
lab def c 0 "Tri-County", modify
append using "hrac_pitc23_data_2022.dta"
append using "hrac_pitc23_data_2023.dta"
save "hrac_pitc23_data_2022-23.dta", replace
export delim using "hrac_pitc23_data_2022-23.csv", replace // csv format
qui {
    log using hrac_pitc23_data_2022-23_codebook.txt, text replace
    nois codebook, compact
    log close
}

// check
bys year: tab county hispan, mis
bys year: tab county health, mis

~!END

// define color schemes
// 1. 3-way 
global c1="forest_green*.9"
global c2="orange*.9"
global c3="eltblue*.9"

// page21/table2
use status county year if year==2023 using "hrac_pitc23_data_2022-23.dta", clear
tablecol status if year==2023, colpct by(county)
xtable status if year==2023, by(county) col filename(tables) sheet(table2) replace

// page22/table3
use status county year using "hrac_pitc23_data_2022-23.dta", clear
tablecol status year, colpct by(county)
xtable status year, by(county) col filename(tables) sheet(table3) modify

// page22/fig2
use status county year using "hrac_pitc23_data_2022-23.dta", clear
 tablecol status year, colpct by(county) replace
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

// page44/table11
use agecat status county hhtype year if year==2023 using "hrac_pitc23_data_2022-23.dta", clear
xtable agecat status, by(county hhtype) mis col row filename(tables) sheet(table11) modify
