***************************************************************;
* Last Update: April 2025                                     *; 
* This code calculates the percentage of busy directors and   *;
* marked a board as either busy board or nonbusy board        *;  
***************************************************************;

******************************************************************
Part 1 : Import data constructed in 1_merge_compcrsp_and_boardex
******************************************************************;

proc import datafile="C:\Users\¤ý«FÒj\Desktop\RA\Cha\Data\compcrsp_board.csv"
	dbms=csv 
	out=data 
	replace;
	guessingrows=1000; 
run;

******************************************************************
Part 2 : Mark each board as busy board or nonbusy board 
******************************************************************;
*
* Steps:
* <1> Construct a table which displays the number of board serve for
*     each DirectorID, save as director_board_count.
* <2> Define a DirectorID as busy director if she serves 3 or more board,
*     save as busy_director_flag.
* <3> Calculate the proportion of busy directors for each firm (gvkey)
* <4> Define a firm as busy board if busy directors account for over half
*     of the board; 

/*step <1>*/
proc sql; 
	create table director_board_count as 
	select DirectorID, fyear, gvkey, board_year, board_month, count(distinct gvkey) as boardcount
	from data group by DirectorID, fyear;
quit; 

/*step <2>*/
data busy_director_flag; 
	set director_board_count;
	if boardcount >= 3 then busy_director = 1;
	else busy_director = 0;
run;

/*step <3> and <4>*/
proc sql;
	create table data_with_busy_director as 
	select a.*, b.busy_director from data as a
	left join busy_director_flag as b 
	on a.gvkey = b.gvkey and a.DirectorID = b.DirectorID and a.fyear = b.fyear;
quit; 

proc sort data=data_with_busy_director out=data_with_busy_director noduprecs;
    by _all_; /*make sure that there are no duplicated rows*/
run;

proc sql; 
	create table board_level_busy as 
	select gvkey, CompanyID, fyear, fyr, mean(busy_director) as busy_ratio,
	calculated busy_ratio > 0.5 as busy_board 
	from data_with_busy_director
	group by gvkey, CompanyID, fyear, fyr;
quit; 

****************************************************************************
Part 3 : Some summary statistics
****************************************************************************;
*
* I observe the distribution of directors based on the number of directorships
* held. In addition, I calculate the proportion of busy board for each year.
* I found that the directors with directorships held equals or more than 3 account
* for about 3-5% for most of the year, while the proportion of companies with busy board
* is about 1% each year. Both of the numbers seems reasonable according to past literature; 

proc freq data=busy_director_flag;
	table fyear*boardcount / nocol nopercent;
	title "Distribution of Directorships Held per Year";
run; 

proc freq data=board_level_busy;
	table busy_board*fyear / norow nopercent;
	title "busy_board proportion";
run; 

proc means data=director_board_count;
	var boardcount;
run;

*******************************************************
Part 4 :¡@Export board_level_busy using .csv file
*******************************************************;
proc export data=board_level_busy 
    outfile="C:\Users\¤ý«FÒj\Desktop\RA\Cha\Data\board_level_busy.csv"
    dbms=csv
    replace;
run;
