-- query: Data for HarmCoefSigma Calc
-- type:  CROSS_TAB
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

TRANSFORM Avg(Cast.Julian_Day) AS AvgOfJulian_Day
SELECT Bottle_Sigm.Sta_ID, Bottle_Sigm.STheta
FROM Cruises INNER JOIN (Cast INNER JOIN Bottle_Sigm ON Cast.Cast_ID = Bottle_Sigm.Cast_ID) ON Cruises.Cruise = Cast.Cruise
WHERE (((Cruises.[Code-ST])="st") AND ((Cruises.Cruise) Between 198400 And 200812))
GROUP BY Bottle_Sigm.Sta_ID, Bottle_Sigm.STheta
PIVOT Cruises.Cruise;
