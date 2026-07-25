-- query: UQ-BtlNum
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Bottle1 INNER JOIN [1995-2009Bottle] ON Bottle1.Btl_Cnt=[1995-2009Bottle].Btl_Cnt
SET Bottle1.BtlNum = [1995-2009Bottle].BtlNum
WHERE (((Bottle1.Depthm)=[1995-2009Bottle].Depthm) And ((Bottle1.Btl_Cnt)=[1995-2009Bottle].Btl_Cnt));
