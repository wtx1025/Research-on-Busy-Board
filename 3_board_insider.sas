********************************************************************;
* Last Update: May 2025                                            *; 
* This code merge the board_level_busy with insider trading data.  *;										  *;															  *;                           *;  
********************************************************************;

******************************************************************************************
Part 1 : Import firm level busy board data we built before and insider trading data
******************************************************************************************;

libname insider "C:\Users\¤ý«FÒj\Desktop\RA\Cha\Data\sales_firmlevel_agg"; *insider trading data;
 
data work.insider;
	set insider.sales_firmlevel_agg;
run;

proc import datafile="C:\Users\¤ý«FÒj\Desktop\RA\Cha\Data\board_level_busy.csv"
	dbms=csv
	out=data
	replace;
run; 

data data;
	set data;
	gvkey_char = put(gvkey, z6.);
run; 

*****************************************************************************
Part 2 : Merge firm level busy board dataset and insider trading dataset 
*****************************************************************************;
*
* According to Compustat's convention, if a company's fiscal year ends in Jan, Feb, 
* Mar, Apr, or May, then the calendar year (cyear) should be defined as the year 
* prior to the fiscal year-end, because most operational activities occur in that year.
* On the other hand, if the fiscal year ends in Jun through Dec, then the calendar year 
* is defined as the same as the fiscal year-end.
* Our data's 'fyear' already reflects this logic, so we can directly merge it with 
* datasets that use calendar year by setting fyear = cyear.;

proc sql;
	create table busy_insider as 
	select d.*, i.cyear, i.calpha_agg, i.cumret_agg, i.tvol_agg, i.tshr_agg from data as d
	left join work.insider as i
	on d.gvkey_char=i.gvkey and d.fyear=i.cyear;
quit; 

data busy_insider;
	set busy_insider;
	if cyear ne .;
run; 

proc print data=busy_insider;
run; 

******************************************************************
Part 3 : Export the merged data using .csv file
******************************************************************;
proc export data=busy_insider 
    outfile="C:\Users\¤ý«FÒj\Desktop\RA\Cha\Data\busy_insider.csv"
    dbms=csv
    replace;
run;





