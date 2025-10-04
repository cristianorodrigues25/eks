<?php

use App\Http\Controllers\HealthController;
use App\Http\Controllers\MetricsController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Health Check endpoints
Route::get('/health', [HealthController::class, 'health']);
Route::get('/ready', [HealthController::class, 'ready']);
Route::get('/live', [HealthController::class, 'live']);

// Metrics endpoint
Route::get('/metrics', [MetricsController::class, 'metrics']);
