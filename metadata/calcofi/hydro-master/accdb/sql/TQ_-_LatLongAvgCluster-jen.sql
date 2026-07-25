-- query: TQ - LatLongAvgCluster-jen
-- type:  CROSS_TAB
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

TRANSFORM Avg(Cast.Lon_Dec) AS AvgOfLon_Dec
SELECT Cast.St_Line, Cast.Rpt_Line
FROM Cast
WHERE (((Cast.Cruise) Between 194901 And 195109))
GROUP BY Cast.St_Line, Cast.Rpt_Line
PIVOT Cast.Cruise;
