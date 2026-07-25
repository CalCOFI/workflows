-- query: UQ_UpdateRpt_Sta_5digits
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Cast
SET Cast.Rpt_Sta = Format(Val(Right([Rpt_Sta],5)),"#.0")
WHERE (((Cast.Rpt_Sta) Like "100" Or (Cast.Rpt_Sta)="110" Or (Cast.Rpt_Sta)="120") AND ((Cast.Cst_Cnt)>=35128));
