<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class MetricsController extends Controller
{
    /**
     * Retorna métricas no formato Prometheus
     */
    public function metrics(): Response
    {
        $metrics = [];

        // Métricas da aplicação
        $metrics[] = $this->formatMetric('app_info', [
            'version' => config('app.version', '1.0.0'),
            'environment' => config('app.env'),
        ], 1);

        // Métricas de memória
        $memoryUsage = memory_get_usage(true);
        $memoryPeak = memory_get_peak_usage(true);
        $metrics[] = '# HELP php_memory_usage_bytes Uso atual de memória';
        $metrics[] = '# TYPE php_memory_usage_bytes gauge';
        $metrics[] = "php_memory_usage_bytes {$memoryUsage}";
        $metrics[] = '# HELP php_memory_peak_usage_bytes Pico de uso de memória';
        $metrics[] = '# TYPE php_memory_peak_usage_bytes gauge';
        $metrics[] = "php_memory_peak_usage_bytes {$memoryPeak}";

        // Métricas de banco de dados
        try {
            $dbConnections = DB::connection()->getDatabaseName() ? 1 : 0;
            $metrics[] = '# HELP database_connected Status da conexão com banco de dados';
            $metrics[] = '# TYPE database_connected gauge';
            $metrics[] = "database_connected {$dbConnections}";
        } catch (\Exception $e) {
            $metrics[] = 'database_connected 0';
        }

        // Métricas de cache
        $cacheHits = Cache::get('metrics_cache_hits', 0);
        $cacheMisses = Cache::get('metrics_cache_misses', 0);
        $metrics[] = '# HELP cache_hits_total Total de acertos no cache';
        $metrics[] = '# TYPE cache_hits_total counter';
        $metrics[] = "cache_hits_total {$cacheHits}";
        $metrics[] = '# HELP cache_misses_total Total de erros no cache';
        $metrics[] = '# TYPE cache_misses_total counter';
        $metrics[] = "cache_misses_total {$cacheMisses}";

        // Métricas de requisições
        $requestCount = Cache::get('metrics_request_count', 0);
        $metrics[] = '# HELP http_requests_total Total de requisições HTTP';
        $metrics[] = '# TYPE http_requests_total counter';
        $metrics[] = "http_requests_total {$requestCount}";

        // Métricas customizadas de negócio
        $metrics[] = '# HELP business_metric_example Exemplo de métrica de negócio';
        $metrics[] = '# TYPE business_metric_example gauge';
        $metrics[] = 'business_metric_example '.rand(1, 100);

        // Incrementa contador de requisições
        Cache::increment('metrics_request_count');

        return response(implode("\n", $metrics), 200)
            ->header('Content-Type', 'text/plain; version=0.0.4');
    }

    /**
     * Formata uma métrica com labels
     */
    private function formatMetric(string $name, array $labels, $value): string
    {
        $labelString = '';
        if (! empty($labels)) {
            $labelPairs = [];
            foreach ($labels as $key => $label) {
                $labelPairs[] = sprintf('%s="%s"', $key, $label);
            }
            $labelString = '{'.implode(',', $labelPairs).'}';
        }

        return sprintf('%s%s %s', $name, $labelString, $value);
    }

    /**
     * Endpoint de status da API
     */
    public function status(): JsonResponse
    {
        $status = [
            'status' => 'operational',
            'timestamp' => now()->toIso8601String(),
            'version' => config('app.version', '1.0.0'),
            'environment' => config('app.env'),
            'uptime' => $this->getUptime(),
            'memory' => [
                'current' => $this->formatBytes(memory_get_usage(true)),
                'peak' => $this->formatBytes(memory_get_peak_usage(true)),
            ],
            'php_version' => PHP_VERSION,
            'laravel_version' => app()->version(),
        ];

        return response()->json($status);
    }

    /**
     * Calcula uptime da aplicação
     */
    private function getUptime(): string
    {
        $laravelStart = defined('LARAVEL_START') ? LARAVEL_START : 0;
        if ($laravelStart > 0) {
            $uptime = microtime(true) - $laravelStart;

            return number_format($uptime, 2).' seconds';
        }

        return 'unknown';
    }

    /**
     * Formata bytes para formato legível
     */
    private function formatBytes($bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB'];
        $i = 0;

        while ($bytes >= 1024 && $i < count($units) - 1) {
            $bytes /= 1024;
            $i++;
        }

        return round($bytes, 2).' '.$units[$i];
    }
}
