************************************************************************;
* Last Update: May 2025                                                *; 
* This codes construct dependent variables and contrl variables used   *;
* for regression analysis.											   *;															  *;                           *;  
************************************************************************;
*
* Independent variable & control variables: 
* <1> ROA is mentioned in footnotes of part C (robustness check. Specifically, it is
*     calulated as operating income before depreciation (item 13) + decrease in receivables
*     (item 2) + decrease in inventory (item 3) + the increase in current liabilities (item 72)
*     + the decrease in other current assets (item 68), scaling by the average of beginning- and
*     ending-year book value of total assets (item 6).  
* <2> ROE is not mentioned in FS (2006), we define it as income before extraordinary items for
*     common equity (item 237) divided by the sum of the book value of equity (item 60) and the
*     deferred taxes (item 74), following Brown and Caylor (2009). 
* <3> Sales over Assets (assets turnover ratio) can be defined as Net sales (item 12) / AT (item 6).
* <4> Tobin's Q calculation can be referred to Perfect and Wiles (1994). We use the simplest version,
*     where q = (COMVAL + PREFVAL + SBOND +STDEBT)/SRC. This version is similar to Chung & Pruitt (1994),
*     where q  =  ((PRCC_F * CSHO) + AT ¡V CEQ ) / AT, since COMVAL=PRCC_F * CSHO and AT - CEQ is like
*     PREFVAL + SBOND + STDEBT. Overall, we calculate Tobin's q by ((item_199*item_25)+item_6-item_60)/item_6.
* <5> Firm size: FS use natural log of sales, natural log of capital, and natural log of assets for proxies. 
* <6> Firm age: According to Strebulaev & Yang (2013), firm age is defined as the number of years in Compustat.
*
* Overall, we need item 13,2,3,72,68,6 for ROA, item 237,60,74 for ROE, item 12,6 for sales over assets,
* item 199,25,6,60 for Tobin's q, item 6 for firm size (the exact item name corresponds to item number can be 
* referred to "Annual Compustat North America Data Items by Number" in Compustat user guide 2003).;  

*************************************************************************************
Part 1 : Import compustat data needed for constructing variables and clean the data 
*************************************************************************************;

proc import datafile="C:\Users\¤ý«FÒj\Desktop\RA\Cha\Data\variable_construction.csv"
	dbms=csv
	out=data
	replace;
run; 

data data;
	set data (keep=gvkey datadate fyear fyr aco at ceq csho ibcom invt lco oibdp rect sale
			  txdb sich prcc_f);
	if not (4900 <= sich <= 4999 or 6900 <= sich <= 6999 or sich=.); /*drop finance and utility firms*/ 
run;

proc sort data=data;
	by gvkey fyear;
run;

data data;
	set data;
	by gvkey fyear; 
	if last.fyear; /*There are some duplicate gvkey+fyear, so we drop them.*/
run; 

********************************************************************
Part 2 : Construct key variables based on past literature. 
********************************************************************;
*
* According to the caculation of ROA in FS (2006), we have to calculate the decrease in receivables,
* inventory, and other current assets, as well as increase in current liabilities. That is, if receivables
* , inventory, and other current assets decrease, we will use it as an increment for ROA, or else we set it
* to 0. For current liabilities, if it increase compared to the previous year, we use it as an increment for
* ROA, or else we set it to 0. After calculating the changes of these variables, we can then caculate variables
* we need. Notes that we have to make sure the denominator isn't zero or missing. If it is missing, we drop the
* data.;

data data(drop=prev_fyear prev_rect prev_invt prev_lco prev_aco);
	set data;
	by gvkey;

	prev_fyear = lag(fyear);
	prev_rect = lag(rect);
	prev_invt = lag(invt);
	prev_lco = lag(lco);  
	prev_aco = lag(aco);

	if first.gvkey then do;
        drect = .;
        dinvt = .;
        ilco  = .;
        daco  = .;
    end;
	else if fyear = prev_fyear + 1 then do;
		drect = max(0, prev_rect - rect);
		dinvt = max(0, prev_invt - invt);
		ilco = max(0, lco - prev_lco);
		daco = max(0, prev_aco - aco);
	end;
	else do;
		drect = .;
		dinvt = .;
		ilco = .;
		daco = .;
	end; 

	if at > 0 then do;
	    roa = (oibdp + drect + dinvt + ilco + daco) / at;
	    asset_turnover = sale / at;
	    tobinsq = (csho * prcc_f + at - ceq) / at;
		size = log(at);
	end;
	else do;
	    roa = .;
	    asset_turnover = .;
	    tobinsq = .;
		size = .;
	end;

	if (ceq + txdb) > 0 then roe = ibcom / (ceq + txdb);
	else roe = .; 

	lagged_roa = lag(roa); 
	lagged_roe = lag(roe);
	lagged_tobinsq = lag(tobinsq);
	lagged_size = lag(size); 
run; 

***************************************************************
Part 3 : Calculate firm age using compustat data from 1950/6 
***************************************************************;
*
* In this part, we calculate firm age by identifying the first year the firm has record on Compustat
* After calculating the age for each gvkey in each year, we merge the age data with the dataset we
* create in part 2. Note that we construct lagged_roa, lagged_roe, lagged_tobinsq, lagged_size, and
* lagged_age as control variables. To be more specific, if our dependent variable (e.g. ROA) is in
* year t+1, then we make sure that these control variables come from year t;

proc import datafile="C:\Users\¤ý«FÒj\Desktop\RA\Cha\Data\compustat_1950.csv"
	dbms=csv
	out=data_1950
	replace;
run; 

proc sort data=data_1950;
	by gvkey fyear;
run;

data data_1950;
	set data_1950;
	by gvkey fyear; 
	if last.fyear; /*There are some duplicate gvkey+fyear, so we drop them.*/
run; 

data gvkey_startyear;
	set data_1950;
	by gvkey;
	if first.gvkey;
	first_fyear = fyear;
	keep gvkey first_fyear;
run;

proc sort data=data_1950;
	by gvkey;
run; 

/*Create a table that record the age of a gvkey in each year*/
proc sql;
	create table data_age as 
	select a.*, b.first_fyear, (a.fyear - b.first_fyear + 1) as age
	from data_1950 as a 
	left join gvkey_startyear as b
	on a.gvkey = b.gvkey;
quit;
 
/*Merge age with other variables, create lagged_age for control variable and drop data
with missing variable*/
proc sql;
	create table data_with_age as 
	select d.*, a.age
	from data as d 
	left join data_age as a
	on d.gvkey = a.gvkey and d.fyear = a.fyear;
quit; 

data final_data (keep=gvkey fyear roa roe asset_turnover tobinsq size lagged_roa lagged_roe lagged_tobinsq
					  lagged_size lagged_age);
	set data_with_age;
	lagged_age = lag(age); 
	if nmiss(roa, roe, asset_turnover, tobinsq, size, lagged_roa, lagged_roe,
			 lagged_tobinsq, lagged_size, lagged_age) = 0;
run; 

*************************************************************
Part 4 : Read busy_insider data and merge it with variables. 
*************************************************************;
*
* In this part, we merge the busy_insider dataset we create in code 3 with the variable dataset
* created in this code. Note that we want the independent variable of interest (e.g. busy_board,
* busy_ratio) to be one year previous than the dependent variable. That is, if our dependent
* variable (e.g. ROA) is in year t+1, then we want busy_ratio to be in year t. In order to do that,
* in this code we create fyear_lagged = fyear + 1 so that we can match busy_ratio in year t with 
* ROA in year t+1.
*
* Overall, the output data will contain dependent variables (roa, roe, asset turnover ratio, tobin's q)
* in year t+1, independent variables (busy_board, busy_ratio) at year t, and control variables (lagged_roa,
* lagged_roe, lagged_tobinsq, lagged_size, lagged_age) at time t.;

proc import datafile="C:\Users\¤ý«FÒj\Desktop\RA\Cha\Data\busy_insider.csv"
	dbms=csv
	out=busy_insider
	replace;
run; 

data busy_insider;
	set busy_insider;
	fyear_lagged = fyear + 1;
	drop fyear;
run; 

proc sql;
	create table regression_data as 
	select f.*, b.* from busy_insider as b
	left join final_data as f
	on b.gvkey = f.gvkey and b.fyear_lagged = f.fyear;
quit; 

data regression_data;
	set regression_data;
	if roa ne .;
run; 