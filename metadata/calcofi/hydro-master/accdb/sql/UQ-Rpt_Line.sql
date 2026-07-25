-- query: UQ-Rpt_Line
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Cast
SET Cast.Rpt_Line = Format(Val(Left(Cast.Sta_ID,5)),"#.0"), Cast.Rpt_Sta = Format(Val(Right(Cast.Sta_ID,5)),"#.0")
WHERE (((Cast.Year)>2008));
