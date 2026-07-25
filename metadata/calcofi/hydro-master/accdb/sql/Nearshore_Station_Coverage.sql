-- query: Nearshore Station Coverage
-- type:  CROSS_TAB
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

TRANSFORM Avg(Cast.Month) AS AvgOfMonth
SELECT Cast.Year
FROM Station_ID INNER JOIN Cast ON Station_ID.DBSta_ID = Cast.DbSta_ID
WHERE (((Cast.St_Line)=83.3 Or (Cast.St_Line)=86.7 Or (Cast.St_Line)=90 Or (Cast.St_Line)=93.3) AND ((Cast.Distance)>-33))
GROUP BY Cast.Year
PIVOT Cast.St_Line;
