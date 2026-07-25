-- query: TR - Zooplankton & Cast: Station
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Zooplankton.Cruise AS Zoo_Cruise, Zooplankton.Sta_ID AS Zoo_St_ID, Cast.St_Line, Zooplankton.Tow_Date
FROM Cast RIGHT JOIN Zooplankton ON Cast.Cruz_Sta=Zooplankton.Cruz_Sta
WHERE (((Cast.Sta_ID) Is Null))
GROUP BY Zooplankton.Cruise, Zooplankton.Sta_ID, Cast.St_Line, Zooplankton.Tow_Date
HAVING (((Zooplankton.Cruise) Between 198400 And 200900));
