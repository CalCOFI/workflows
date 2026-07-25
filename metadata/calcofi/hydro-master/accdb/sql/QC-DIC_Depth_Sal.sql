-- query: QC-DIC_Depth_Sal
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Abs(Mid([Depth_ID],33,3)-([D_Depth1])) AS Depth_ID_Compare, [0808DIC_DB].Depth_ID AS Depth_ID, Abs([StaSalt]-[Salinity1]) AS sal_comp, [0808DIC_DB].StaSalt AS StaSalnty, [0808DIC_DB].Salinity1 AS DIC_Salnty, [0808DIC_DB].Ord_Occ, [0808DIC_DB].Bottle_ID, [0808DIC_DB].Bottle_ID2, [0808DIC_DB].Btl_Cnt, [0808DIC_DB].ID, [0808DIC_DB].StaSalt
FROM 0808DIC_DB
WHERE ((([0808DIC_DB].StaSalt) Is Not Null));
