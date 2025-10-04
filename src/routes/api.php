<?php

use App\Http\Controllers\MetricsController;
use Illuminate\Support\Facades\Route;

// API Status endpoint
Route::get('/status', [MetricsController::class, 'status']);
