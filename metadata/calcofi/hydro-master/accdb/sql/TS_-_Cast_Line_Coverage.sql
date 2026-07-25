-- query: TS - Cast: Line  Coverage
-- type:  CROSS_TAB
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

TRANSFORM Count(Cast.Cast_ID) AS CountOfCast_ID
SELECT Cruises.Cruise
FROM Cruises INNER JOIN (Station_ID INNER JOIN Cast ON Station_ID.Sta_ID = Cast.Sta_ID) ON Cruises.Cruise = Cast.Cruise
WHERE (((Cast.St_Line)=76.7 Or (Cast.St_Line)=80 Or (Cast.St_Line)=83.3 Or (Cast.St_Line)=86.7 Or (Cast.St_Line)=90 Or (Cast.St_Line)=93.3) AND ((Station_ID.Sta_Code)="st")) OR (((Cast.St_Line) Between 76.5 And 77.2))
GROUP BY Cruises.Cruise
PIVOT Cast.St_Line;
