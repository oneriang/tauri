<?php
/* config.user.inc.php */
$cfg['Servers'][1]['auth_type'] = 'cookie'; // 或 'http' / 'config'
$cfg['Servers'][1]['user'] = 'root';        // 仅当 auth_type 为 config 时需要
$cfg['Servers'][1]['password'] = 'rootpass';// 同上
