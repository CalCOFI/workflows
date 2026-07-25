-- query: TS - Cast: Line Chl  Coverage
-- type:  CROSS_TAB
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

TRANSFORM Count(Chl.ChlorA) AS CountOfChlorA
SELECT Cast.Cruise
FROM (Cast INNER JOIN Bottle ON Cast.Cst_Cnt = Bottle.Cst_Cnt) INNER JOIN Chl ON Bottle.Btl_Cnt = Chl.Btl_Cnt
WHERE (((Cast.St_Line)=76.7 Or (Cast.St_Line)=80 Or (Cast.St_Line)=83.3 Or (Cast.St_Line)=86.7 Or (Cast.St_Line)=90 Or (Cast.St_Line)=93.3) AND ((Chl.ChlorA) Is Not Null))
GROUP BY Cast.Cruise
PIVOT Cast.St_Line;
