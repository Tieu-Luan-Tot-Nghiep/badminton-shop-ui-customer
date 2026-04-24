import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/datasources/shipping_remote_data_source.dart';
import '../../data/repositories/shipping_repository_impl.dart';
import '../../domain/entities/address_entity.dart';
import '../../domain/entities/province_entity.dart';
import '../../domain/entities/district_entity.dart';
import '../../domain/entities/ward_entity.dart';
import '../manager/address_controller.dart';

class AddressFormPage extends StatefulWidget {
  const AddressFormPage({super.key, required this.controller, this.address});

  final AddressController controller;
  final AddressEntity? address;

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _specificAddressController;
  bool _isDefault = false;

  // Shipping data
  late final ShippingRepositoryImpl _shippingRepo;
  List<ProvinceEntity> _provinces = [];
  List<DistrictEntity> _districts = [];
  List<WardEntity> _wards = [];
  
  ProvinceEntity? _selectedProvince;
  DistrictEntity? _selectedDistrict;
  WardEntity? _selectedWard;
  
  bool _isLoadingProvinces = false;
  bool _isLoadingDistricts = false;
  bool _isLoadingWards = false;

  @override
  void initState() {
    super.initState();
    _shippingRepo = ShippingRepositoryImpl(ShippingRemoteDataSource());
    
    final address = widget.address;
    _nameController = TextEditingController(text: address?.receiverName ?? '');
    _phoneController = TextEditingController(text: address?.phoneNumber ?? '');
    _specificAddressController = TextEditingController(text: address?.specificAddress ?? '');
    _isDefault = address?.isDefault ?? false;
    
    _loadProvinces();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _specificAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    setState(() => _isLoadingProvinces = true);
    try {
      final provinces = await _shippingRepo.getProvinces();
      setState(() {
        _provinces = provinces;
        _isLoadingProvinces = false;
      });
    } catch (e) {
      setState(() => _isLoadingProvinces = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải danh sách tỉnh/thành phố: $e')),
        );
      }
    }
  }

  Future<void> _loadDistricts(int provinceId) async {
    setState(() {
      _isLoadingDistricts = true;
      _districts = [];
      _wards = [];
      _selectedDistrict = null;
      _selectedWard = null;
    });
    try {
      final districts = await _shippingRepo.getDistricts(provinceId);
      setState(() {
        _districts = districts;
        _isLoadingDistricts = false;
      });
    } catch (e) {
      setState(() => _isLoadingDistricts = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải danh sách quận/huyện: $e')),
        );
      }
    }
  }

  Future<void> _loadWards(int districtId) async {
    setState(() {
      _isLoadingWards = true;
      _wards = [];
      _selectedWard = null;
    });
    try {
      final wards = await _shippingRepo.getWards(districtId);
      setState(() {
        _wards = wards;
        _isLoadingWards = false;
      });
    } catch (e) {
      setState(() => _isLoadingWards = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải danh sách phường/xã: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProvince == null || _selectedDistrict == null || _selectedWard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn đầy đủ Tỉnh/Thành phố, Quận/Huyện và Phường/Xã')),
      );
      return;
    }

    final address = AddressEntity(
      id: widget.address?.id ?? 0,
      receiverName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      province: _selectedProvince!.provinceName,
      district: _selectedDistrict!.districtName,
      ward: _selectedWard!.wardName,
      specificAddress: _specificAddressController.text.trim(),
      isDefault: _isDefault,
    );

    final success = widget.address == null
        ? await widget.controller.addAddress(address)
        : await widget.controller.updateAddress(address);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.address == null ? 'Đã thêm địa chỉ mới' : 'Đã cập nhật địa chỉ')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.address != null;

    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      appBar: AppBar(
        title: Text(isEdit ? 'SỬA ĐỊA CHỈ' : 'THÊM ĐỊA CHỈ MỚI', style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(controller: _nameController, label: 'HỌ VÀ TÊN NGƯỜI NHẬN', icon: Icons.person_outline_rounded),
              const SizedBox(height: 16),
              _buildTextField(controller: _phoneController, label: 'SỐ ĐIỆN THOẠI', icon: Icons.phone_android_rounded, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildProvinceDropdown(),
              const SizedBox(height: 16),
              _buildDistrictDropdown(),
              const SizedBox(height: 16),
              _buildWardDropdown(),
              const SizedBox(height: 16),
              _buildTextField(controller: _specificAddressController, label: 'ĐỊA CHỈ CHI TIẾT (SỐ NHÀ, TÊN ĐƯỜNG...)', icon: Icons.home_work_outlined, maxLines: 2),
              const SizedBox(height: 16),
              _buildDefaultSwitch(),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: widget.controller.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.onPrimaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: widget.controller.isLoading
                      ? const CircularProgressIndicator()
                      : Text(isEdit ? 'CẬP NHẬT ĐỊA CHỈ' : 'THÊM ĐỊA CHỈ', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.textPrimary),
          validator: (v) => v == null || v.isEmpty ? 'Trường này là bắt buộc' : null,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primaryContainer),
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: AppColors.primaryContainer),
              const SizedBox(width: 12),
              const Text('Đặt làm địa chỉ mặc định', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
          Switch(
            value: _isDefault,
            onChanged: (v) => setState(() => _isDefault = v),
            activeColor: AppColors.primaryContainer,
          ),
        ],
      ),
    );
  }

  Widget _buildProvinceDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TỈNH / THÀNH PHỐ',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _isLoadingProvinces
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : DropdownButtonFormField<ProvinceEntity>(
                  value: _selectedProvince,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_city_rounded, color: AppColors.primaryContainer),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  hint: const Text('Chọn Tỉnh/Thành phố', style: TextStyle(color: AppColors.textSecondary)),
                  dropdownColor: AppColors.surfaceContainerLow,
                  style: const TextStyle(color: AppColors.textPrimary),
                  validator: (v) => v == null ? 'Vui lòng chọn Tỉnh/Thành phố' : null,
                  items: _provinces.map((province) {
                    return DropdownMenuItem<ProvinceEntity>(
                      value: province,
                      child: Text(province.provinceName),
                    );
                  }).toList(),
                  onChanged: (province) {
                    setState(() => _selectedProvince = province);
                    if (province != null) {
                      _loadDistricts(province.provinceId);
                    }
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDistrictDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QUẬN / HUYỆN',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _isLoadingDistricts
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : DropdownButtonFormField<DistrictEntity>(
                  value: _selectedDistrict,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.map_outlined, color: AppColors.primaryContainer),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  hint: Text(
                    _selectedProvince == null ? 'Chọn Tỉnh/Thành phố trước' : 'Chọn Quận/Huyện',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  dropdownColor: AppColors.surfaceContainerLow,
                  style: const TextStyle(color: AppColors.textPrimary),
                  validator: (v) => v == null ? 'Vui lòng chọn Quận/Huyện' : null,
                  items: _districts.map((district) {
                    return DropdownMenuItem<DistrictEntity>(
                      value: district,
                      child: Text(district.districtName),
                    );
                  }).toList(),
                  onChanged: _selectedProvince == null
                      ? null
                      : (district) {
                          setState(() => _selectedDistrict = district);
                          if (district != null) {
                            _loadWards(district.districtId);
                          }
                        },
                ),
        ),
      ],
    );
  }

  Widget _buildWardDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PHƯỜNG / XÃ',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _isLoadingWards
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : DropdownButtonFormField<WardEntity>(
                  value: _selectedWard,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.explore_outlined, color: AppColors.primaryContainer),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  hint: Text(
                    _selectedDistrict == null ? 'Chọn Quận/Huyện trước' : 'Chọn Phường/Xã',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  dropdownColor: AppColors.surfaceContainerLow,
                  style: const TextStyle(color: AppColors.textPrimary),
                  validator: (v) => v == null ? 'Vui lòng chọn Phường/Xã' : null,
                  items: _wards.map((ward) {
                    return DropdownMenuItem<WardEntity>(
                      value: ward,
                      child: Text(ward.wardName),
                    );
                  }).toList(),
                  onChanged: _selectedDistrict == null
                      ? null
                      : (ward) {
                          setState(() => _selectedWard = ward);
                        },
                ),
        ),
      ],
    );
  }
}
