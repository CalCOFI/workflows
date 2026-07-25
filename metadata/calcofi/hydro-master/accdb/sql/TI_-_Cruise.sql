-- query: TI - Cruise
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cruises.Cruise, Cruises.[Code-ST], Cruises.Ship1, Cruises.BegDate1, Cruises.EndDate1
FROM Cruises
WHERE (((Cruises.Cruise)>198400) AND ((Cruises.[Code-ST])="st"));
