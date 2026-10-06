-- ============================================================
-- 星云音乐 · 数据库初始化脚本（MySQL 8）
-- 软件版权：星云云络科技；音乐版权：小枯
-- 引擎 InnoDB / 字符集 utf8mb4；金额 DECIMAL(10,2)，点数 INT
-- 普通表均带 created_at / updated_at（日志类仅 created_at）
-- ============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ------------------------------------------------------------
-- 7.1 用户与设备
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS users (
  id             BIGINT PRIMARY KEY AUTO_INCREMENT,
  device_id      BIGINT       NULL COMMENT '主设备ID',
  nickname       VARCHAR(64)  NULL,
  avatar         VARCHAR(255) NULL,
  email          VARCHAR(128) NULL,
  email_verified TINYINT      DEFAULT 0,
  mobile         VARCHAR(20)  NULL COMMENT '预留',
  status         TINYINT      DEFAULT 1 COMMENT '1正常 0封禁',
  risk_level     TINYINT      DEFAULT 0 COMMENT '0正常 1可疑 2高危',
  last_login_at  DATETIME     NULL,
  created_at     DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_email (email),
  KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

CREATE TABLE IF NOT EXISTS user_devices (
  id          BIGINT       PRIMARY KEY AUTO_INCREMENT,
  user_id     BIGINT       NOT NULL,
  platform    VARCHAR(10)  NOT NULL COMMENT 'ios/android',
  udid_norm   VARCHAR(64)  NOT NULL COMMENT '归一化UDID(去横线小写)',
  raw_udid    VARCHAR(80)  NULL,
  idfv        VARCHAR(64)  NULL,
  android_id  VARCHAR(32)  NULL,
  fingerprint JSON         NULL,
  model       VARCHAR(64)  NULL,
  os_version  VARCHAR(32)  NULL,
  is_emulator TINYINT      DEFAULT 0,
  is_root     TINYINT      DEFAULT 0,
  risk        TINYINT      DEFAULT 0 COMMENT '0正常 1可疑 2高危',
  first_seen  DATETIME     NULL,
  last_seen   DATETIME     NULL,
  created_at  DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_udid (udid_norm),
  KEY idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='设备表（一机一号锚点）';

-- ------------------------------------------------------------
-- 7.2 会员与点数
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS memberships (
  id                    BIGINT      PRIMARY KEY AUTO_INCREMENT,
  user_id               BIGINT      NOT NULL,
  type                  VARCHAR(10) NOT NULL COMMENT 'music/ai',
  plan                  VARCHAR(12) NOT NULL COMMENT 'month/quarter/half/year/forever',
  status                TINYINT     DEFAULT 1 COMMENT '1有效 0失效',
  started_at            DATETIME    NULL,
  expire_at             DATETIME    NULL COMMENT '永久为NULL',
  auto_renew            TINYINT     DEFAULT 0,
  gift_buyout_remaining INT         DEFAULT 0 COMMENT '季卡以上剩余赠送买断次数',
  order_no              VARCHAR(40) NULL,
  created_at            DATETIME    DEFAULT CURRENT_TIMESTAMP,
  updated_at            DATETIME    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_user_type (user_id, type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='会员表（两类独立）';

CREATE TABLE IF NOT EXISTS point_accounts (
  user_id        BIGINT PRIMARY KEY,
  balance        INT     DEFAULT 0 COMMENT '可用点数',
  frozen         INT     DEFAULT 0 COMMENT '冻结点数',
  total_recharge INT     DEFAULT 0,
  total_consume  INT     DEFAULT 0,
  updated_at     DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='点数账户';

CREATE TABLE IF NOT EXISTS point_logs (
  id            BIGINT       PRIMARY KEY AUTO_INCREMENT,
  user_id       BIGINT       NOT NULL,
  type          VARCHAR(12)  NOT NULL COMMENT 'recharge/gift/consume/freeze/refund',
  amount        INT          NOT NULL COMMENT '正增负减',
  balance_after INT          NULL,
  biz_type      VARCHAR(20)  NULL,
  biz_id        VARCHAR(64)  NULL,
  remark        VARCHAR(255) NULL,
  created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,
  KEY idx_user (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='点数流水';

-- ------------------------------------------------------------
-- 7.3 订单与卡密
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS orders (
  id           BIGINT        PRIMARY KEY AUTO_INCREMENT,
  order_no     VARCHAR(40)   NOT NULL,
  user_id      BIGINT        NOT NULL,
  goods_type   VARCHAR(12)   NOT NULL COMMENT 'point/music_vip/ai_vip/buyout/shared',
  goods_name   VARCHAR(128)  NULL,
  amount       DECIMAL(10,2) NOT NULL,
  pay_channel  VARCHAR(12)   NULL COMMENT 'epay/card',
  pay_method   VARCHAR(12)   NULL COMMENT 'wxpay/alipay',
  status       VARCHAR(12)   DEFAULT 'pending' COMMENT 'pending/paid/closed/refunded/processing',
  out_trade_no VARCHAR(64)   NULL COMMENT '上游交易号',
  card_key     VARCHAR(64)   NULL,
  meta         JSON          NULL,
  paid_at      DATETIME      NULL,
  created_at   DATETIME      DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_order_no (order_no),
  KEY idx_user_status (user_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单表';

CREATE TABLE IF NOT EXISTS card_keys (
  id         BIGINT      PRIMARY KEY AUTO_INCREMENT,
  card_no    VARCHAR(40) NOT NULL,
  card_type  VARCHAR(12) NOT NULL COMMENT 'point/music_vip/ai_vip/buyout/shared',
  face_value VARCHAR(40) NULL COMMENT '点数面值/会员时长',
  status     VARCHAR(10) DEFAULT 'unused' COMMENT 'unused/used/expired',
  batch_no   VARCHAR(40) NULL,
  user_id    BIGINT      NULL,
  used_at    DATETIME    NULL,
  expire_at  DATETIME    NULL,
  created_at DATETIME    DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_card_no (card_no),
  KEY idx_type_status (card_type, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='卡密表（五类）';

-- ------------------------------------------------------------
-- 7.4 歌曲与音源、AI 上游
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS songs (
  id               BIGINT       PRIMARY KEY AUTO_INCREMENT,
  source_id        BIGINT       NULL,
  platform         VARCHAR(20)  NULL,
  platform_song_id VARCHAR(64)  NULL,
  name             VARCHAR(128) NOT NULL,
  artist           VARCHAR(128) NULL,
  album            VARCHAR(128) NULL,
  duration         INT          NULL,
  cover            VARCHAR(255) NULL,
  lyric            MEDIUMTEXT   NULL,
  quality          VARCHAR(10)  NULL,
  status           TINYINT      DEFAULT 1 COMMENT '1上架 0下架',
  created_at       DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_platform_song (platform, platform_song_id),
  KEY idx_name (name),
  KEY idx_artist (artist)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='歌曲表';

CREATE TABLE IF NOT EXISTS music_sources (
  id         BIGINT       PRIMARY KEY AUTO_INCREMENT,
  name       VARCHAR(64)  NOT NULL,
  type       VARCHAR(20)  NULL COMMENT 'navidrome/music-lib/musicfree/listen1/meting',
  base_url   VARCHAR(255) NULL,
  secret     VARCHAR(255) NULL,
  priority   INT          DEFAULT 99 COMMENT '数字小优先',
  weight     INT          DEFAULT 1,
  enabled    TINYINT      DEFAULT 1,
  timeout    INT          DEFAULT 5,
  retry      INT          DEFAULT 1,
  health     TINYINT      DEFAULT 1,
  last_check DATETIME     NULL,
  created_at DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='音源表（一主三备）';

CREATE TABLE IF NOT EXISTS ai_providers (
  id           BIGINT        PRIMARY KEY AUTO_INCREMENT,
  name         VARCHAR(64)   NOT NULL,
  base_url     VARCHAR(255)  NULL,
  api_key      VARCHAR(255)  NULL,
  model        VARCHAR(64)   NULL,
  model_alias  VARCHAR(64)   NULL,
  cost_price   DECIMAL(10,3) NULL COMMENT '每首成本',
  priority     INT           DEFAULT 99,
  enabled      TINYINT       DEFAULT 1,
  success_rate DECIMAL(5,2)  DEFAULT 0,
  created_at   DATETIME      DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI上游表（后台任意对接）';

-- ------------------------------------------------------------
-- 7.5 生成任务与授权
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS gen_tasks (
  id          BIGINT        PRIMARY KEY AUTO_INCREMENT,
  user_id     BIGINT        NOT NULL,
  task_no     VARCHAR(40)   NOT NULL,
  lyric_mode  VARCHAR(12)   NULL,
  prompt      VARCHAR(1000) NULL,
  lyrics      MEDIUMTEXT    NULL,
  genre       VARCHAR(128)  NULL,
  gender      VARCHAR(8)    NULL,
  duration    INT           NULL,
  status      VARCHAR(12)   DEFAULT 'created',
  progress    INT           DEFAULT 0,
  provider_id BIGINT        NULL,
  output_url  VARCHAR(255)  NULL,
  storage_key VARCHAR(255)  NULL COMMENT '转存对象存储键',
  error       VARCHAR(255)  NULL,
  points_cost INT           DEFAULT 10,
  created_at  DATETIME      DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_task_no (task_no),
  KEY idx_user (user_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI生成任务表';

CREATE TABLE IF NOT EXISTS licenses (
  id              BIGINT        PRIMARY KEY AUTO_INCREMENT,
  user_id         BIGINT        NOT NULL,
  task_id         BIGINT        NULL,
  song_key        VARCHAR(120)  NULL,
  type            VARCHAR(10)   NOT NULL COMMENT 'buyout/shared',
  status          TINYINT       DEFAULT 1,
  price           DECIMAL(10,2) NULL,
  platform        VARCHAR(64)   NULL COMMENT '共有：目标平台',
  artist_name     VARCHAR(128)  NULL COMMENT '共有：艺名',
  share_ratio     VARCHAR(20)   NULL,
  certificate_url VARCHAR(255)  NULL,
  agreement_url   VARCHAR(255)  NULL,
  created_at      DATETIME      DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='授权表（买断/共有）';

-- ------------------------------------------------------------
-- 7.6 其余表
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS favorites (
  id         BIGINT   PRIMARY KEY AUTO_INCREMENT,
  user_id    BIGINT   NOT NULL,
  song_id    BIGINT   NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_user_song (user_id, song_id),
  KEY idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='收藏';

CREATE TABLE IF NOT EXISTS playlists (
  id         BIGINT       PRIMARY KEY AUTO_INCREMENT,
  user_id    BIGINT       NOT NULL,
  name       VARCHAR(128) NOT NULL,
  cover      VARCHAR(255) NULL,
  song_count INT          DEFAULT 0,
  created_at DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='歌单';

CREATE TABLE IF NOT EXISTS playlist_songs (
  id          BIGINT   PRIMARY KEY AUTO_INCREMENT,
  playlist_id BIGINT   NOT NULL,
  song_id     BIGINT   NOT NULL,
  sort        INT      DEFAULT 0,
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_playlist_song (playlist_id, song_id),
  KEY idx_playlist (playlist_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='歌单歌曲';

CREATE TABLE IF NOT EXISTS ads_config (
  id            BIGINT       PRIMARY KEY AUTO_INCREMENT,
  platform      VARCHAR(20)  NOT NULL COMMENT 'pangle/gromore/youlianghui/ks',
  app_id        VARCHAR(64)  NULL,
  placement_id  VARCHAR(64)  NULL,
  enabled       TINYINT      DEFAULT 0,
  reward_type   VARCHAR(20)  NULL COMMENT 'trial/download/music_vip_trial',
  reward_amount INT          DEFAULT 0,
  daily_limit   INT          DEFAULT 5,
  created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='广告配置';

CREATE TABLE IF NOT EXISTS ad_rewards (
  id          BIGINT      PRIMARY KEY AUTO_INCREMENT,
  user_id     BIGINT      NOT NULL,
  ad_platform VARCHAR(20) NULL,
  callback_id VARCHAR(64) NULL,
  reward      VARCHAR(64) NULL,
  status      VARCHAR(12) DEFAULT 'pending' COMMENT 'pending/granted/rejected',
  created_at  DATETIME    DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='广告奖励';

CREATE TABLE IF NOT EXISTS payment_channels (
  id         BIGINT       PRIMARY KEY AUTO_INCREMENT,
  code       VARCHAR(20)  NOT NULL COMMENT 'epay/card',
  name       VARCHAR(64)  NULL,
  config     JSON         NULL,
  enabled    TINYINT      DEFAULT 1,
  visible    TINYINT      DEFAULT 1,
  sort       INT          DEFAULT 0,
  created_at DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='支付通道';

CREATE TABLE IF NOT EXISTS announcements (
  id         BIGINT        PRIMARY KEY AUTO_INCREMENT,
  title      VARCHAR(128)  NOT NULL,
  content    TEXT          NULL,
  type       VARCHAR(20)   DEFAULT 'notice' COMMENT 'notice/banner/popup',
  publish_at DATETIME      NULL,
  enabled    TINYINT       DEFAULT 0,
  created_at DATETIME      DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='公告';

-- ---- RBAC（管理员/角色/菜单） ----

CREATE TABLE IF NOT EXISTS admin_users (
  id            BIGINT       PRIMARY KEY AUTO_INCREMENT,
  username      VARCHAR(64)  NOT NULL,
  password      VARCHAR(128) NOT NULL COMMENT 'BCrypt',
  nickname      VARCHAR(64)  NULL,
  email         VARCHAR(128) NULL,
  is_super      TINYINT      DEFAULT 0 COMMENT '1超级管理员',
  status        TINYINT      DEFAULT 1,
  last_login_at DATETIME     NULL,
  created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='管理员';

CREATE TABLE IF NOT EXISTS roles (
  id         BIGINT       PRIMARY KEY AUTO_INCREMENT,
  name       VARCHAR(64)  NOT NULL,
  code       VARCHAR(64)  NOT NULL,
  remark     VARCHAR(255) NULL,
  created_at DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='角色';

CREATE TABLE IF NOT EXISTS admin_role (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  admin_id   BIGINT NOT NULL,
  role_id    BIGINT NOT NULL,
  UNIQUE KEY uk_admin_role (admin_id, role_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='管理员-角色关联';

CREATE TABLE IF NOT EXISTS menus (
  id         BIGINT       PRIMARY KEY AUTO_INCREMENT,
  parent_id  BIGINT       DEFAULT 0,
  name       VARCHAR(64)  NOT NULL,
  perm       VARCHAR(64)  NULL COMMENT '权限标识如 song:offline',
  type       VARCHAR(10)  DEFAULT 'menu' COMMENT 'menu/button',
  path       VARCHAR(128) NULL,
  sort       INT          DEFAULT 0,
  created_at DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='菜单';

CREATE TABLE IF NOT EXISTS role_menu (
  id      BIGINT PRIMARY KEY AUTO_INCREMENT,
  role_id BIGINT NOT NULL,
  menu_id BIGINT NOT NULL,
  UNIQUE KEY uk_role_menu (role_id, menu_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='角色-菜单关联';

-- ---- 配置中心 ----

CREATE TABLE IF NOT EXISTS sys_config (
  id           BIGINT        PRIMARY KEY AUTO_INCREMENT,
  config_group VARCHAR(64)   NULL,
  config_key   VARCHAR(128)  NOT NULL,
  config_value TEXT          NULL,
  remark       VARCHAR(255)  NULL,
  created_at   DATETIME      DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_config_key (config_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统配置';

-- ---- 日志（仅 created_at） ----

CREATE TABLE IF NOT EXISTS login_logs (
  id         BIGINT       PRIMARY KEY AUTO_INCREMENT,
  subject    VARCHAR(64)  NULL COMMENT '用户ID/管理员名',
  kind       VARCHAR(10)  DEFAULT 'user' COMMENT 'user/admin',
  ip         VARCHAR(45)  NULL,
  device     VARCHAR(128) NULL,
  result     VARCHAR(10)  NULL COMMENT 'success/fail',
  created_at DATETIME     DEFAULT CURRENT_TIMESTAMP,
  KEY idx_subject (subject)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='登录日志';

CREATE TABLE IF NOT EXISTS operation_logs (
  id         BIGINT       PRIMARY KEY AUTO_INCREMENT,
  subject    VARCHAR(64)  NULL,
  kind       VARCHAR(10)  DEFAULT 'user' COMMENT 'user/admin',
  action     VARCHAR(128) NULL,
  target     VARCHAR(128) NULL,
  ip         VARCHAR(45)  NULL,
  result     VARCHAR(10)  NULL,
  created_at DATETIME     DEFAULT CURRENT_TIMESTAMP,
  KEY idx_subject (subject)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='操作日志';

SET FOREIGN_KEY_CHECKS = 1;