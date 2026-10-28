package config

type Config struct {
	Log          LogConfig
	DB           DBConfig
	Server       ServerConfig
	Detector     DetectorConfig
	Telemetry    TelemetryConfig
	GPRC         GRPCConfig
	PlatformAddr string
	MgtResDir    string
	NgxResDir    string
}

func DefaultGlobalConfig() Config {
	return Config{
		Log:       DefaultLogConfig(),
		DB:        DefaultDBConfig(),
		Server:    DefaultServerConfig(),
		Detector:  DefaultDetectorConfig(),
		Telemetry: DefaultTelemetryConfig(),
		GPRC:      DefaultGRPCConfig(),
		// SAFELOCAL: the platform base used by the upgrade/version check. GetUpgradeTips
		// is neutralised below, and this default points at a closed local port so no
		// path can reach Chaitin's waf-ce.chaitin.cn even if the check were re-enabled.
		PlatformAddr: "http://127.0.0.1:1",
		MgtResDir:    "/resources/management",
		NgxResDir:    "/resources/nginx",
	}
}
