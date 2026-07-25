-- query: UQ_reupdateProdo
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE 1411_btldb INNER JOIN Prodo_Bottle ON [1411_btldb].Btl_Cnt = Prodo_Bottle.Btl_Cnt
SET Prodo_Bottle.C14As1 = [1411_btldb].[C14As1], Prodo_Bottle.C14A1p = [1411_btldb].[C14A1p], Prodo_Bottle.C14A1q = [1411_btldb].[C14A1q], Prodo_Bottle.C14As2 = [1411_btldb].[C14As2], Prodo_Bottle.C14A2p = [1411_btldb].[C14A2p], Prodo_Bottle.C14A2q = [1411_btldb].[C14A2q], Prodo_Bottle.DarkAs = [1411_btldb].[DarkAs], Prodo_Bottle.DarkAp = [1411_btldb].[DarkAp], Prodo_Bottle.DarkAq = [1411_btldb].[DarkAq], Prodo_Bottle.MeanAs = [1411_btldb].[MeanAs], Prodo_Bottle.MeanAp = [1411_btldb].[MeanAp], Prodo_Bottle.MeanAq = [1411_btldb].[MeanAq], Prodo_Bottle.IncTim = [1411_btldb].[IncTim], Prodo_Bottle.LightP = [1411_btldb].[LightP];
