<?php

header('Content-Type: application/json');

$uri = $_SERVER['REQUEST_URI'];
$path = parse_url($uri, PHP_URL_PATH);

if ($path === '/api/health') {
    $results = [];
    $allPassed = true;

    // PHP version
    $results['php'] = [
        'status' => 'ok',
        'version' => PHP_VERSION,
    ];

    // Required extensions
    $requiredExtensions = ['pdo', 'pdo_mysql', 'redis', 'json', 'intl', 'zip'];
    $extensions = [];
    foreach ($requiredExtensions as $ext) {
        $loaded = extension_loaded($ext);
        $extensions[$ext] = $loaded ? 'ok' : 'missing';
        if (!$loaded) $allPassed = false;
    }
    $results['extensions'] = $extensions;

    // MySQL
    try {
        $dsn = sprintf('mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
            getenv('DB_HOST'), getenv('DB_PORT'), getenv('DB_NAME'));
        $pdo = new PDO($dsn, getenv('DB_USER'), getenv('DB_PASS'), [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_TIMEOUT => 5,
        ]);
        $version = $pdo->query('SELECT VERSION()')->fetchColumn();
        $row = $pdo->query('SELECT COUNT(*) as cnt FROM preflight_check')->fetch(PDO::FETCH_ASSOC);
        $results['mysql'] = [
            'status' => 'ok',
            'version' => $version,
            'test_query' => 'passed (read ' . $row['cnt'] . ' rows)',
        ];
    } catch (Exception $e) {
        $results['mysql'] = ['status' => 'error', 'message' => $e->getMessage()];
        $allPassed = false;
    }

    // Redis
    try {
        $redis = new Redis();
        $connected = $redis->connect(getenv('REDIS_HOST'), (int)getenv('REDIS_PORT'), 5);
        if (!$connected) throw new Exception('Connection failed');
        $redis->set('preflight_test', 'ok', 10);
        $val = $redis->get('preflight_test');
        $results['redis'] = [
            'status' => 'ok',
            'server_info' => $redis->info('server')['redis_version'] ?? 'unknown',
            'test_write_read' => $val === 'ok' ? 'passed' : 'failed',
        ];
        $redis->close();
    } catch (Exception $e) {
        $results['redis'] = ['status' => 'error', 'message' => $e->getMessage()];
        $allPassed = false;
    }

    // Mailpit
    try {
        $mailHost = getenv('MAIL_HOST');
        $mailPort = (int)getenv('MAIL_PORT');
        $sock = @fsockopen($mailHost, $mailPort, $errno, $errstr, 5);
        if ($sock) {
            fclose($sock);
            $results['mailpit'] = ['status' => 'ok', 'smtp_port' => $mailPort];
        } else {
            throw new Exception("Cannot connect to $mailHost:$mailPort - $errstr");
        }
    } catch (Exception $e) {
        $results['mailpit'] = ['status' => 'error', 'message' => $e->getMessage()];
        $allPassed = false;
    }

    $response = [
        'overall' => $allPassed ? 'ALL CHECKS PASSED' : 'SOME CHECKS FAILED',
        'checks' => $results,
    ];

    http_response_code($allPassed ? 200 : 500);
    echo json_encode($response, JSON_PRETTY_PRINT) . "\n";
    exit;
}

http_response_code(404);
echo json_encode(['error' => 'Not found. Try /api/health']) . "\n";
