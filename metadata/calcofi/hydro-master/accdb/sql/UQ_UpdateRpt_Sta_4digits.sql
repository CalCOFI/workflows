-- query: UQ_UpdateRpt_Sta_4digits
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Cast
SET Cast.Rpt_Sta = Format(Val(Right([Rpt_Sta],4)),"#.0")
WHERE (((Cast.Rpt_Sta) Like "28" Or (Cast.Rpt_Sta)="30" Or (Cast.Rpt_Sta)="35" Or (Cast.Rpt_Sta)="37" Or (Cast.Rpt_Sta)="45" Or (Cast.Rpt_Sta)="50" Or (Cast.Rpt_Sta)="53" Or (Cast.Rpt_Sta)="60" Or (Cast.Rpt_Sta)="55" Or (Cast.Rpt_Sta)="70" Or (Cast.Rpt_Sta)="80" Or (Cast.Rpt_Sta)="90" Or (Cast.Rpt_Sta)="42" Or (Cast.Rpt_Sta)="51" Or (Cast.Rpt_Sta)="33" Or (Cast.Rpt_Sta)="40" Or (Cast.Rpt_Sta)="49") AND ((Cast.Cst_Cnt)>=35128));
