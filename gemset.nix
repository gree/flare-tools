{
  builder = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "045wzckxpwcqzrjr353cxnyaxgf0qg22jh00dcx7z38cys5g1jlr";
      type = "gem";
    };
    version = "3.2.4";
  };
  ci_reporter = {
    dependencies = ["builder"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ccvgs8wq7mhwk1mn4aff4p2k6ima934safb4y7f5bn6xm3y6y99";
      type = "gem";
    };
    version = "1.9.3";
  };
  log4r = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0ri90q0frfmigkirqv5ihyrj59xm8pq5zcmf156cbdv4r4l2jicv";
      type = "gem";
    };
    version = "1.1.10";
  };
  power_assert = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1y2c5mvkq7zc5vh4ijs1wc9hc0yn4mwsbrjch34jf11pcz116pnd";
      type = "gem";
    };
    version = "2.0.3";
  };
  psych = {
    dependencies = ["stringio"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1msambb54r3d1sg6smyj4k2pj9h9lz8jq4jamip7ivcyv32a85vz";
      type = "gem";
    };
    version = "5.1.0";
  };
  rake = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "15whn7p9nrkxangbs9hh75q585yfn66lv0v2mhj6q6dl6x8bzr2w";
      type = "gem";
    };
    version = "13.0.6";
  };
  rdoc = {
    dependencies = ["psych"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "05r2cxscapr9saqjw8dlp89as7jvc2mlz1h5kssrmkbz105qmfcm";
      type = "gem";
    };
    version = "6.5.0";
  };
  stringio = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0ix96dxbjqlpymdigb4diwrifr0bq7qhsrng95fkkp18av326nqk";
      type = "gem";
    };
    version = "3.0.8";
  };
  test-unit = {
    dependencies = ["power_assert"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "02v0aa6rfanas00p47xi0anbza1ymcgv6h03ipil8pbj21cw998a";
      type = "gem";
    };
    version = "3.6.1";
  };
  tokyocabinet = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1bq90igiqsqq08gigmsiqkrg28j44g09gs3nr2hk4d4dqmadv91c";
      type = "gem";
    };
    version = "1.32.0";
  };
  zookeeper = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1hc87pbmgc53lksa1aql61kxn9d2kjzmlhnjxa5rcn01qhm3pkvg";
      type = "gem";
    };
    version = "1.5.5";
  };
}
