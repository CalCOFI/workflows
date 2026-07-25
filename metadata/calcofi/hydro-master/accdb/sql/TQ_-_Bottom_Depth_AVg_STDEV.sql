-- query: TQ - Bottom Depth_AVg_STDEV
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Avg(Cast.Bottom_D) AS AvgOfBottom_D, Cast.Sta_ID, StDev(Cast.Bottom_D) AS StDevOfBottom_D, Cast.St_Line, Min(Cast.Bottom_D) AS MinOfBottom_D, Max(Cast.Bottom_D) AS MaxOfBottom_D, Count(Cast.Sta_Code) AS CountOfSta_Code
FROM Cast
WHERE (((Cast.Sta_Code)="st") AND ((Cast.Year)>1983))
GROUP BY Cast.Sta_ID, Cast.St_Line
HAVING (((StDev(Cast.Bottom_D)) Is Not Null) AND ((Cast.St_Line)>76.6 And (Cast.St_Line)<93.5))
ORDER BY StDev(Cast.Bottom_D);
