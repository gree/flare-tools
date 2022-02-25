{
  builder = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0qibi5s67lpdv1wgcj66wcymcr04q6j4mzws6a479n0mlrmh5wr1";
      type = "gem";
    };
    version = "3.2.3";
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
      sha256 = "1x5qcfm8ka7anaady81qahhn9y4f6j86kvyqma7d2hnri4ahflvh";
      type = "gem";
    };
    version = "1.1.3";
  };
  rake = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1cvaqarr1m84mhc006g3l1vw7sa5qpkcw0138lsxlf769zdllsgp";
      type = "gem";
    };
    version = "12.3.3";
  };
  rdoc = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "06lbn2v4fapd8cqjq00nsipmisyghsgykv50lwns7959p8jvfkfc";
      type = "gem";
    };
    version = "6.3.1";
  };
  test-unit = {
    dependencies = ["power_assert"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0ik96zhzb3mzmmz7ls6sv5d3149sspvr83mq3z6pknbn09qc1c1y";
      type = "gem";
    };
    version = "3.3.0";
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
      sha256 = "06i33nf1b9hsb19na42yvxmiplijw994dhij1f71cp8n4krhymhv";
      type = "gem";
    };
    version = "1.5.1";
  };
  flare-tools = {
    dependencies = ["log4r" "tokyocabinet"];
    groups = ["default"];
    platforms = [];
    source = {
      path = ./.;
      type = "path";
    };
    version = "0.0.1";
  };
}
