-- query: TR - Zooplankton
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Zooplankton.Cruise, Zooplankton.Order_Occ, Zooplankton.Tow_Date, Zooplankton.Sta_ID, Zooplankton.Cruz_Sta, Zooplankton.St_Line, Zooplankton.St_Sta, Zooplankton.Net_Loc
FROM Zooplankton INNER JOIN Station_ID ON Zooplankton.Sta_ID = Station_ID.Sta_ID
GROUP BY Zooplankton.Cruise, Zooplankton.Order_Occ, Zooplankton.Tow_Date, Zooplankton.Sta_ID, Zooplankton.Cruz_Sta, Zooplankton.St_Line, Zooplankton.St_Sta, Zooplankton.Net_Loc
HAVING (((Zooplankton.Cruise)=196009) AND ((Zooplankton.Net_Loc)="S"))
ORDER BY Zooplankton.Sta_ID;
