***************************************************************;
* Last Update: April 2025                                     *; 
* This code merge Compustat and CRSP data with Boardex data.  *;
* Both data are in firm year level, we use the link table to  *; 
* merge two files.   										  *;															  *;                           *;  
***************************************************************;

******************************************************************************************
Part 1 : Import Compustate & CRSP data, Boardex data, link table, and historical SIC data
******************************************************************************************;

libname comp "C:\Users\¤ý«FÒj\Desktop\RA\Cha\Data\comp_crsp_00_23"; *Compustat & CRSP data;
libname boardex "C:\Users\¤ý«FÒj\Desktop\RA\Cha\Data\org_summary_2020mar"; *Boardex data;
libname link "C:\Users\¤ý«FÒj\Desktop\RA\Cha\Data\boardex_crsp_comp"; *Link table; 
 
data work.compcrsp;
	set comp.comp_crsp_00_23;
run;

data work.boardex;
	set boardex.org_summary_2020mar;
run;

data work.link;
	set link.boardex_crsp_comp;
run; 

proc import datafile="C:\Users\¤ý«FÒj\Desktop\RA\Cha\Data\gvkey_sich.csv" /*historical SIC*/ 
	dbms=csv
	out=sich
	replace;
run;

data sich;
	set sich (keep=gvkey fyear sich);
	gvkey_char = put(gvkey, z6.);
run;

******************************************************************
Part 2 : Merge work.compcrsp and work.boardex using work.link
******************************************************************;
*
* Var in compcsrp: gvkey, datadate, fyear, fyr, permno, permco, NCUSIP
* Var in boardex: NED, Gender, BoardID, DirectorID, AnnualReportDate,CIKCode,
*                 HOCountryName, GenderRatio, NationalityMix, NumberDirectors, CompanyID
* Var in link: COMPANYID, PERMCO, GVKEY, SCORE, PREFERRED, DUPLICATE
* Var in sic: gvkey, fyear, sich  
*
* Steps:
* <1> Dealing with the link table, find out the best match (A gvkey is matched to only 1 companyID).
*     Note that a gvkey may correspond to different companyID in the link table. To deal with this, I
*     first select only records with preferred=1. Then, for each gvkey, retain the record with the 
*     lowest score (best matching quality). If a gvkey correspond to different companyID and have the
*     same score, I simply kept the one with smallest companyID.
* <2> Merge historical SIC into work.compcrsp and exclude utility and financial companies (4900-4999, 6900-6999),
*     according to FS (2006). Also, we drop data where sich is missing value. The output data is 
*     compcrsp_without_utility_finance.
* <3> Merge compcrsp_without_utility_finance with link table via gvkey, save as compcrsp_with_companyID.
*     Here I use gvkey instead of permco to merge datasets because gvkey uniquely identifies financial 
*     reporting entities in Compustat, which suit our research. Moreover, different gvkeys can correspond
*     to the same CompanyID , indicating that multiple reporting entities (e.g., parent and subsidiary
*     companies) may share the same board structures.
* <4> Merge compcrsp_with_companyID with boardex data via companyID and year and month, save as compcrsp_board. 
*     I observe that DirectorID count for specific CompanyID in specific year may exceed NumberDirectors.
*     It may be the result that boardex data records all board members throughout the year, while NumberDirectors 
*     reflects a point-in-time snapshot, according to https://metalib.ie.edu/ayuda/Varios/BoardExWRDSDataDictionary.pdf;

/*Step <1>*/ 
data link_preferred_all;
	set work.link;
	where preferred=1;
run;

proc sort data=link_preferred_all out=link_preferred_sorted;
	by gvkey score companyID;
run;

data link_preferred;
	set link_preferred_sorted;
	by gvkey;
	if first.gvkey; /*keep the sample with smallest score, companyID*/ 
run; 

/*Step <2>*/
/*Exclude utility and financial companies*/ 
proc sort data=sich nodupkey; /*This process remove same gvkey and fyear but with different sich*/
	by gvkey_char fyear;
run;

proc sql;
	create table compcrsp_with_sic as 
	select a.*, b.sich from work.compcrsp as a 
	left join sich as b on a.gvkey=b.gvkey_char and a.fyear=b.fyear;
run; 

data compcrsp_without_utility_finance;
	set compcrsp_with_sic;
	if not (4900 <= sich <= 4999 or 6900 <= sich <= 6999 or sich=.);
run;
 
/*Step <3>*/ 
proc sql; /*Merge compcrsp_without_utility_finance & work.link*/
	create table compcrsp_with_companyID as 
	select c.*, l.COMPANYID from compcrsp_without_utility_finance as c
	left join link_preferred as l on c.gvkey=l.gvkey; 
quit;

data compcrsp_with_companyID;
	set compcrsp_with_companyID;
	if CompanyID ne .;
	/*because not every gvkey in compcrsp_without_utility_finance
	is in the link table, so some of the gvkey in compcrsp_with_companyID
	migth has missing companyID*/
run; 

/*Step <4>*/ 
data boardex;
	set boardex;
	board_year = year(AnnualReportDate);
	board_month = month(AnnualReportDate);
	if HOCountryName = 'United States'; 
	/*extract year from date in order to merge with compcrsp_with_companyID*/ 
run; 

proc sort data=boardex out=boardex noduprecs;
    by _all_;
run;

data compcrsp_with_companyID;
	set compcrsp_with_companyID;
	year = year(datadate);
	month = month(datadate);
run; 

proc sql; 
	/*Merge compcrsp_with_companyID and boardex, there may be several directors 
	for a companyID at specific year*/
	create table compcrsp_board as 
	select c.*, b.NED, b.BoardID, DirectorID, AnnualReportDate, b.NumberDirectors, b.board_year, b.board_month
	from compcrsp_with_companyID as c
	left join boardex as b
	on c.companyID=b.companyID and c.year=b.board_year and c.month=b.board_month;
quit; 

data compcrsp_board; 
	/*Some CompanyID in compcrsp_with_companyID does not appear in boardex in some years,
    resulting in missing DirectorID, so we have to drop data without DirectorID.*/
	set compcrsp_board;
	if DirectorID ne .;
run; 

******************************************************************
Part 3 : Export the merged data using .csv file
******************************************************************;
proc export data=compcrsp_board
    outfile="C:\Users\¤ý«FÒj\Desktop\RA\Cha\Data\compcrsp_board.csv"
    dbms=csv
    replace;
run;




