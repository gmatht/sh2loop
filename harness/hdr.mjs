import { sh2 } from "./sh2-namespace.mjs";   // hdr.mjs lives in harness/
sh2._init("/tmp/captest2/mm5.sh", []);
sh2.vars.x = "";
