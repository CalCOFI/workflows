-- query: UQ_UpdateRpt_Line
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Cast
SET Cast.Rpt_Line = Format(Val(Right([Rpt_Line],4)),"#.0")
WHERE (((Cast.Rpt_Line) Like "90" Or (Cast.Rpt_Line)="80" Or (Cast.Rpt_Line)="70" Or (Cast.Rpt_Line)="60") AND ((Cast.Cst_Cnt)>=35959));
