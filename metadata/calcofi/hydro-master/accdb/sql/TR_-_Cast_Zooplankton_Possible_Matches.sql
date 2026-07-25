-- query: TR - Cast & Zooplankton: Possible Matches
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT [TR - Cast & Zooplankton: Station].Cruise, [TR - Cast & Zooplankton: Station].Sta_ID, [TR - Cast & Zooplankton: Station].DateTime, ZooplanktonNew.Cruise, ZooplanktonNew.Sta_ID, ZooplanktonNew.DateTime_GMT
FROM [TR - Cast & Zooplankton: Station], ZooplanktonNew
WHERE (((ZooplanktonNew.Lat_Dec) Between ([TR - Cast & Zooplankton: Station]!Lat_Dec+0.2) And ([TR - Cast & Zooplankton: Station]!Lat_Dec-0.2)) And ((ZooplanktonNew.Lon_Dec) Between ([TR - Cast & Zooplankton: Station]!Lon_Dec+0.2) And ([TR - Cast & Zooplankton: Station]!Lon_Dec-0.2)) And ((ZooplanktonNew.DateTime_GMT) Between ([TR - Cast & Zooplankton: Station]!DateTime-0.3) And ([TR - Cast & Zooplankton: Station]!DateTime+0.3)))
GROUP BY [TR - Cast & Zooplankton: Station].Cruise, [TR - Cast & Zooplankton: Station].Sta_ID, [TR - Cast & Zooplankton: Station].DateTime, ZooplanktonNew.Cruise, ZooplanktonNew.Sta_ID, ZooplanktonNew.DateTime_GMT;
