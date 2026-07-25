-- query: MT-Cast_113Sta
-- type:  MAKE_TABLE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast_All.* INTO Cast_113Sta
FROM Cast_All
WHERE (((Cast_All.St_Line)<94 And (Cast_All.St_Line)>59.5) AND ((Cast_All.St_Station)<130));
