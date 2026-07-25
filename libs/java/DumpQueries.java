// libs/java/DumpQueries.java
// -----------------------------------------------------------------------------
// Dump every saved query in an MS Access .mdb/.accdb to CSV, using Jackcess.
//
// WHY THIS EXISTS: mdbtools' `mdb-queries` reconstructs query SQL from the stored
// parse tree only partially — it silently drops JOIN clauses, GROUP BY, HAVING and
// column aliases, and emits `SELECT  FROM ` for queries it cannot parse at all. The
// output looks like valid SQL and is semantically wrong (a LEFT JOIN find-unmatched
// query degrades into a cross join). Jackcess's Query#toSQLString() walks the same
// parse tree faithfully, so it is the authoritative extractor; mdbtools is kept only
// as a cross-check (see accdb_diff_query_sql() in libs/extract_accdb.R).
//
// Emits ONE csv on purpose. Fanning out to per-query .sql files is done in R so the
// filename-sanitizing rule lives in exactly one place.
//
// Usage:  java -cp "<jar-dir>/*" DumpQueries.java <db-file> <out-csv>
// Needs:  jackcess, commons-lang3, commons-logging (versions pinned in
//         scripts/extract_accdb.sh). Java 11+ (single-file source execution).
//
// Known limitation, do not treat as a bug in this file: queries mixing inner and
// outer joins across the same table pair throw IllegalStateException
// ("Inconsistent join types") inside Jackcess. Those rows come back ok=false with the
// message in `error`; the caller asserts on the expected count rather than failing.

import com.healthmarketscience.jackcess.Database;
import com.healthmarketscience.jackcess.DatabaseBuilder;
import com.healthmarketscience.jackcess.query.Query;

import java.io.File;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

public class DumpQueries {

  /** RFC4180 field: wrap in quotes, double any embedded quote. */
  private static String csv(String s) {
    if (s == null) return "\"\"";
    return "\"" + s.replace("\"", "\"\"") + "\"";
  }

  public static void main(String[] args) throws Exception {
    if (args.length != 2) {
      System.err.println("usage: DumpQueries <db-file> <out-csv>");
      System.exit(2);
    }
    File dbFile = new File(args[0]);
    Path outCsv = Paths.get(args[1]);
    if (outCsv.getParent() != null) Files.createDirectories(outCsv.getParent());

    int ok = 0, failed = 0;

    try (Database db = new DatabaseBuilder(dbFile).setReadOnly(true).open();
         PrintWriter out = new PrintWriter(
             Files.newBufferedWriter(outCsv, StandardCharsets.UTF_8))) {

      out.println("query_name,query_type,ok,error,sql");

      // sort by name so the CSV is byte-stable across runs (diffable in git)
      List<Query> queries = new ArrayList<>(db.getQueries());
      queries.sort(Comparator.comparing(Query::getName));

      for (Query q : queries) {
        String name  = q.getName();
        String type  = String.valueOf(q.getType());
        String sql   = "";
        String error = "";
        boolean good = true;

        try {
          sql = q.toSQLString();
          ok++;
        } catch (Exception e) {
          good  = false;
          error = e.getClass().getSimpleName() + ": " + e.getMessage();
          failed++;
        }

        out.println(String.join(",",
            csv(name), csv(type), String.valueOf(good), csv(error), csv(sql)));
      }
    }

    // stdout is parsed by the caller — keep this line's shape stable
    System.out.println("queries=" + (ok + failed) + " ok=" + ok + " failed=" + failed);
  }
}
