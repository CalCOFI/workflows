-- query: TQ - BottomDepthPerStation
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Bottom_D, Cast.Cst_Cnt, Cast.Cruise_ID, Cast.Cast_ID
FROM Cast
GROUP BY Cast.Bottom_D, Cast.Cst_Cnt, Cast.Cruise_ID, Cast.Cast_ID, Cast.Sta_ID
HAVING (((Cast.Sta_ID)="076.7 049.0"));
