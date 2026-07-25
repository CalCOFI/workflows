-- query: MT-Bottle_113Sta
-- type:  MAKE_TABLE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast_All.DbSta_ID, Bottle_All.* INTO Bottle_113sta
FROM Cast_All INNER JOIN Bottle_All ON Cast_All.Cst_Cnt=Bottle_All.Cst_Cnt
WHERE (((Cast_All.St_Line)<94 And (Cast_All.St_Line)>59.5) AND ((Cast_All.St_Station)<130));
