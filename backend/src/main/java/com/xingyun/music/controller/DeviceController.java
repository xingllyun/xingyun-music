package com.xingyun.music.controller;

import com.xingyun.music.common.ApiResponse;
import com.xingyun.music.dto.DeviceReportRequest;
import com.xingyun.music.dto.DeviceReportResponse;
import com.xingyun.music.service.DeviceService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/device")
@RequiredArgsConstructor
public class DeviceController {

    private final DeviceService deviceService;

    @PostMapping("/report")
    public ApiResponse<DeviceReportResponse> report(@Valid @RequestBody DeviceReportRequest req) {
        return ApiResponse.ok(deviceService.report(req));
    }
}