package config

import (
	"chaitin.cn/dev/go/settings"
)

type ServerConfig struct {
	ListenAddr  string `yaml:"listen_addr"`
	DevMode     bool   `yaml:"dev_mode"`
	IntenseMode bool   `yaml:"intense_mode"`
}

func DefaultServerConfig() ServerConfig {
	return ServerConfig{
		// SAFELOCAL: align the API listen port with the bundled nginx upstream
		// (conf.d/default.conf proxies /api to 127.0.0.1:8000). The stock
		// default :9001 left nginx with a broken upstream on a self-hosted box.
		ListenAddr: ":8000",
		DevMode:    false,
	}
}

func (sc *ServerConfig) Load(setting *settings.Setting) error {
	if err := setting.Unmarshal("server", sc); err != nil {
		return err
	}

	return nil
}
