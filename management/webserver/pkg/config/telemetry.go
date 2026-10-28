package config

import (
	"chaitin.cn/dev/go/settings"
)

type TelemetryConfig struct {
	Addr string `yaml:"addr"`
}

func DefaultTelemetryConfig() TelemetryConfig {
	// SAFELOCAL: telemetry is disabled (DoPostTelemetry is a no-op). The default
	// points at a closed local port so that even a re-enabled caller can never
	// reach Chaitin's rivers-telemetry host.
	return TelemetryConfig{
		Addr: "127.0.0.1:1",
	}
}

func (t *TelemetryConfig) Load(setting *settings.Setting) error {
	if err := setting.Unmarshal("telemetry", t); err != nil {
		return err
	}

	return nil
}
