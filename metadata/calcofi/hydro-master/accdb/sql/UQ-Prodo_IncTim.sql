-- query: UQ-Prodo_IncTim
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Prodo_Cast INNER JOIN Prodo_Bottle ON Prodo_Cast.Cst_Cnt = Prodo_Bottle.Cst_Cnt
SET Prodo_Bottle.IncTim = Format(Abs([Prodo_Cast].[Inc_Str]-[Prodo_Cast].[Inc_End]),"Long Time")
WHERE (((Prodo_Bottle.C14As1) Is Not Null) AND ((Prodo_Bottle.C14As2) Is Not Null) AND ((Prodo_Bottle.DarkAs) Is Not Null) AND ((Prodo_Bottle.Btl_Cnt)>=887236));
