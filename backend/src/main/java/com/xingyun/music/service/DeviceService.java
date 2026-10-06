package com.xingyun.music.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.xingyun.music.common.BizException;
import com.xingyun.music.common.ErrorCode;
import com.xingyun.music.dto.DeviceReportRequest;
import com.xingyun.music.dto.DeviceReportResponse;
import com.xingyun.music.entity.User;
import com.xingyun.music.entity.UserDevice;
import com.xingyun.music.mapper.UserDeviceMapper;
import com.xingyun.music.mapper.UserMapper;
import com.xingyun.music.util.JwtUtil;
import com.xingyun.music.util.UdidUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

/**
 * 设备上报与一机一号校验（M1 核心）。
 */
@Service
@RequiredArgsConstructor
public class DeviceService {

    private final UserDeviceMapper deviceMapper;
    private final UserMapper userMapper;
    private final JwtUtil jwtUtil;

    @Transactional
    public DeviceReportResponse report(DeviceReportRequest req) {
        String udidNorm = UdidUtil.normalize(req.udid());
        if (udidNorm == null || udidNorm.isBlank()) {
            throw BizException.of(ErrorCode.PARAM_ERROR);
        }
        int risk = calcRisk(req.isEmulator(), req.isRoot());

        UserDevice device = deviceMapper.selectOne(
                Wrappers.lambdaQuery(UserDevice.class).eq(UserDevice::getUdidNorm, udidNorm));

        if (device == null) {
            device = new UserDevice();
            device.setPlatform(req.platform());
            device.setUdidNorm(udidNorm);
            device.setRawUdid(req.udid());
            device.setIdfv(req.idfv());
            device.setAndroidId(req.androidId());
            device.setFingerprint(req.fingerprint());
            device.setModel(req.model());
            device.setOsVersion(req.osVersion());
            device.setIsEmulator(boolToInt(req.isEmulator()));
            device.setIsRoot(boolToInt(req.isRoot()));
            device.setRisk(risk);
            device.setFirstSeen(LocalDateTime.now());
            device.setLastSeen(LocalDateTime.now());
            deviceMapper.insert(device);
            return new DeviceReportResponse(device.getId(), false, null, null);
        }

        // 已存在设备，更新最近活跃与风险
        device.setLastSeen(LocalDateTime.now());
        device.setRisk(risk);
        device.setModel(req.model());
        device.setOsVersion(req.osVersion());
        deviceMapper.updateById(device);

        if (device.getUserId() == null) {
            return new DeviceReportResponse(device.getId(), false, null, null);
        }

        // 已绑定：校验账号状态后自动登录
        User user = userMapper.selectById(device.getUserId());
        if (user == null) {
            throw BizException.of(ErrorCode.ACCOUNT_DISABLED);
        }
        if (user.getStatus() != null && user.getStatus() != 1) {
            throw BizException.of(ErrorCode.ACCOUNT_DISABLED);
        }
        user.setLastLoginAt(LocalDateTime.now());
        userMapper.updateById(user);

        String token = jwtUtil.generate(user.getId());
        return new DeviceReportResponse(device.getId(), true, user.getId(), token);
    }

    private int calcRisk(Boolean isEmulator, Boolean isRoot) {
        if (Boolean.TRUE.equals(isEmulator) || Boolean.TRUE.equals(isRoot)) {
            return 2;
        }
        return 0;
    }

    private int boolToInt(Boolean b) {
        return Boolean.TRUE.equals(b) ? 1 : 0;
    }
}