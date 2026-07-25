-- query: Temp Line90 -MT
-- type:  CROSS_TAB
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

TRANSFORM Avg(Bottle.T_degC) AS AvgOfT_degC
SELECT Cast.Year, Cast.Cruise, Avg(Cast.Date) AS Date, (Month([Date])+Day([Date])/30.5-1) AS Month, Avg(Cast.Quarter) AS AvgOfQuarter
FROM (Station_ID INNER JOIN Cast ON Station_ID.Sta_ID = Cast.Sta_ID) INNER JOIN Bottle ON Cast.Cst_Cnt = Bottle.Cst_Cnt
WHERE (((Bottle.Depthm)=10) AND ((Station_ID.St_Line)=90) AND ((Station_ID.Sta_Code)="st"))
GROUP BY Cast.Year, Cast.Cruise
PIVOT Cast.Sta_ID;
