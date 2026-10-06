package com.xingyun.music.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.xingyun.music.common.BizException;
import com.xingyun.music.common.ErrorCode;
import com.xingyun.music.dto.LoginResponse;
import com.xingyun.music.dto.RegisterRequest;
import com.xingyun.music.entity.PointAccount;
import com.xingyun.music.entity.User;
import com.xingyun.music.entity.UserDevice;
import com.xingyun.music.mapper.PointAccountMapper;
import com.xingyun.music.mapper.UserDeviceMapper;
import com.xingyun.music.mapper.UserMapper;
import com.xingyun.music.util.JwtUtil;
import com.xingyun.music.util.UdidUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

/**
 * 账号注册（一机一号绑定）与登录。
 */
@Service
@RequiredArgsConstructor
public class AccountService {

    private final UserMapper userMapper;
    private final UserDeviceMapper deviceMapper;
    private final PointAccountMapper pointAccountMapper;
    private final JwtUtil jwtUtil;

    @Transactional
    public LoginResponse register(RegisterRequest req) {
        String udidNorm = UdidUtil.normalize(req.udid());
        UserDevice device = deviceMapper.selectOne(
                Wrappers.lambdaQuery(UserDevice.class).eq(UserDevice::getUdidNorm, udidNorm));
        if (device == null) {
            throw BizException.of(ErrorCode.PARAM_ERROR);
        }
        if (device.getUserId() != null) {
            // 一机一号：设备已绑定其他账号
            throw BizException.of(ErrorCode.DEVICE_BOUND);
        }

        User user = new User();
        user.setNickname(req.nickname() == null || req.nickname().isBlank()
                ? "星云用户" + System.currentTimeMillis() % 100000
                : req.nickname());
        user.setStatus(1);
        user.setRiskLevel(device.getRisk());
        user.setLastLoginAt(LocalDateTime.now());
        userMapper.insert(user);

        device.setUserId(user.getId());
        device.setLastSeen(LocalDateTime.now());
        deviceMapper.updateById(device);

        user.setDeviceId(device.getId());
        userMapper.updateById(user);

        PointAccount account = new PointAccount();
        account.setUserId(user.getId());
        account.setBalance(0);
        account.setFrozen(0);
        account.setTotalRecharge(0);
        account.setTotalConsume(0);
        account.setUpdatedAt(LocalDateTime.now());
        pointAccountMapper.insert(account);

        return buildLoginResponse(user, 0);
    }

    public LoginResponse profile(Long userId) {
        User user = userMapper.selectById(userId);
        if (user == null || user.getStatus() == null || user.getStatus() != 1) {
            throw BizException.of(ErrorCode.NOT_LOGIN);
        }
        PointAccount account = pointAccountMapper.selectById(userId);
        int balance = account != null && account.getBalance() != null ? account.getBalance() : 0;
        return buildLoginResponse(user, balance);
    }

    private LoginResponse buildLoginResponse(User user, int balance) {
        return new LoginResponse(
                jwtUtil.generate(user.getId()),
                user.getId(),
                user.getNickname(),
                user.getAvatar(),
                balance);
    }
}