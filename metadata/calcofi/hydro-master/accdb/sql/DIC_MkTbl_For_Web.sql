-- query: DIC_MkTbl_For_Web
-- type:  MAKE_TABLE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT DICs.ID, [Bottle.Cst_Cnt] AS Cast_Index, [Bottle.Btl_Cnt] AS Bottle_Index, Cast.Cruise, [Bottle.Depthm] AS [Depth(m)], [Cast.Sta_ID] AS [Line Sta_ID], Bottle.Depth_ID, DICs.DIC1, DICs.DIC2, DICs.TA1, DICs.TA2, DICs.pH1, DICs.pH2, DICs.Salinity1, DICs.Salinity2, [Bottle.T_degC] AS Temperature_degC, [Bottle.Salnty] AS [Bottle Salinity], [bottle.O2ml_L] AS [Bottle O2(ml_L)], [bottle.Oxy_µmol/Kg] AS [Bottle O2 (µmol/Kg)], [bottle.STheta] AS [Sigma-theta], [Dics.Bottle_ID1] AS [DIC Bottle_ID1], [Dics.Bottle_ID2] AS [DIC Bottle_ID2], DICs.[DIC Quality Comment] INTO Web_DICs
FROM Cast INNER JOIN (Bottle INNER JOIN DICs ON Bottle.Btl_Cnt = DICs.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt;
