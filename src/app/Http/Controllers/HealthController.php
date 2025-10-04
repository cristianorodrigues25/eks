<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;

class HealthController extends Controller
{
    /**
     * Endpoint de verificação de saúde para Kubernetes
     * Verifica: Banco de dados, Cache, Sistema de arquivos
     */
    public function health(): JsonResponse
    {
        $checks = [
            'database' => $this->checkDatabase(),
            'cache' => $this->checkCache(),
            'filesystem' => $this->checkFilesystem(),
        ];

        $healthy = ! in_array(false, $checks, true);

        return response()->json([
            'status' => $healthy ? 'saudável' : 'não saudável',
            'timestamp' => now()->toIso8601String(),
            'version' => config('app.version', '1.0.0'),
            'environment' => config('app.env'),
            'checks' => $checks,
        ], $healthy ? 200 : 503);
    }

    /**
     * Verifica conexão com banco de dados
     */
    private function checkDatabase(): bool
    {
        try {
            DB::select('SELECT 1');

            return true;
        } catch (\Exception $e) {
            return false;
        }
    }

    /**
     * Verifica se o cache está funcionando
     */
    private function checkCache(): bool
    {
        try {
            $key = 'health_check_'.time();
            Cache::put($key, true, 10);
            $result = Cache::get($key);
            Cache::forget($key);

            return $result === true;
        } catch (\Exception $e) {
            return false;
        }
    }

    /**
     * Verifica se o filesystem está acessível
     */
    private function checkFilesystem(): bool
    {
        try {
            $path = storage_path('app/health_check.tmp');
            File::put($path, 'test');
            $content = File::get($path);
            File::delete($path);

            return $content === 'test';
        } catch (\Exception $e) {
            return false;
        }
    }

    /**
     * Endpoint de readiness para Kubernetes
     */
    public function ready(): JsonResponse
    {
        // Verifica apenas componentes críticos
        $isReady = $this->checkDatabase();

        return response()->json([
            'ready' => $isReady,
            'timestamp' => now()->toIso8601String(),
        ], $isReady ? 200 : 503);
    }

    /**
     * Endpoint de liveness para Kubernetes
     */
    public function live(): JsonResponse
    {
        // Sempre retorna OK se a aplicação está rodando
        return response()->json([
            'alive' => true,
            'timestamp' => now()->toIso8601String(),
        ]);
    }
}
