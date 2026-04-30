import React, { useState, useEffect } from "react";
import {
  Building2,
  Building,
  Users,
  Mail,
  Phone,
  Lock,
  Eye,
  EyeOff,
  Upload,
  FileText,
  CheckCircle,
  AlertCircle,
  ArrowLeft,
  ArrowRight,
  Globe,
  Hash,
  X,
} from "lucide-react";
import AdaptioMark from "../../components/AdaptioMark";

import taxIdRules from "../../../tax_id_rules_global_en.json";
import phoneRules from "../../../phone_number_rules_global_full.json";
import blockedEmailDomains from "../../../blocked_email_domains_for_company_registration.json";

export default function CompanyRegistration() {
  const [currentStep, setCurrentStep] = useState(1);
  const totalSteps = 5;

  const [formData, setFormData] = useState({
    companyName: "",
    country: "",
    industry: "",
    companySize: "",
    contactFirstName: "",
    contactLastName: "",
    contactEmail: "",
    website: "",
    phoneCountryCode: "",
    phoneNumber: "",
    businessRegistrationNumber: "",
    // ⚠️ Lo dejo por compatibilidad (no lo usamos en el flujo para evitar inconsistencias)
    corporateEmail: "",
    password: "",
    confirmPassword: "",
  });

  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [isSubmitted, setIsSubmitted] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [uploadedFiles, setUploadedFiles] = useState<File[]>([]);
  const [taxIdDocument, setTaxIdDocument] = useState<File | null>(null);

  const [otpCode, setOtpCode] = useState(["", "", "", "", "", ""]);

  const [isPartOfGroup] = useState(false);
  const [groupCode] = useState("");
  const [vapCode] = useState("");
  const [referralCode, setReferralCode] = useState("");

  const [cameFromLogin, setCameFromLogin] = useState(false);

  const [userMode, setUserMode] = useState<"new_user" | "existing_user" | null>(
    null
  );
  const [existingUserId, setExistingUserId] = useState<string | null>(null);
  const [isCheckingEmail, setIsCheckingEmail] = useState(false);

  // Detect if user came from login page
  useEffect(() => {
    const referrer = document.referrer;
    const currentOrigin = window.location.origin;
    const loginPage = `${currentOrigin}/login`;

    if (referrer === loginPage) {
      setCameFromLogin(true);
    }
  }, []);

  // Industry options
  const industryOptions = [
    "Agriculture & Forestry",
    "Architecture & Interior Design",
    "Arts & Culture",
    "Business Services (BPO, HR, Facilities)",
    "Construction",
    "Education & Training",
    "Electronics & Hardware",
    "Energy & Utilities",
    "Financial Services & Banking",
    "Food & Beverage",
    "Government & Public Sector",
    "Healthcare & Medical",
    "Hospitality & Tourism",
    "Information Technology & Software",
    "Insurance",
    "Internet Services & SaaS",
    "Marketing & Advertising",
    "Manufacturing",
    "Media & Entertainment",
    "Mining & Metals",
    "Nonprofit & NGOs",
    "Personal Services",
    "Pharmaceuticals & Biotech",
    "Professional Services (Consulting, Legal, Accounting)",
    "Real Estate & Property Management",
    "Retail & eCommerce",
    "Telecommunications",
    "Transportation & Logistics",
    "Wholesale & Distribution",
    "Other / Not Listed",
  ];

  // Company size options
  const companySizeOptions = [
    "1-10 employees",
    "11-50 employees",
    "51-200 employees",
    "201-500 employees",
    "501-1000 employees",
    "1001-5000 employees",
    "5000+ employees",
  ];

  // Helper: Tax ID info
  const getTaxIdInfo = (countryCode: string) => {
    const rule = taxIdRules.rules.find(
      (r: any) => r.country_code === countryCode
    );
    return rule || taxIdRules.fallback;
  };

  // Helper: Phone info
  const getPhoneInfo = (callingCode: string) => {
    const rule = phoneRules.rules.find(
      (r: any) => r.calling_code === callingCode
    );
    return rule || phoneRules.fallback;
  };

  const phoneCountryCodes = [
    { code: "+1", flag: "🇺🇸", country: "United States", iso: "USA" },
    { code: "+1", flag: "🇨🇦", country: "Canada", iso: "CAN" },
    { code: "+507", flag: "🇵🇦", country: "Panama", iso: "PAN" },
    // ... (deja tu lista completa tal cual la tenías)
  ].sort((a, b) => a.iso.localeCompare(b.iso));

  const countries = [
    { code: "PA", name: "Panama" },
    { code: "US", name: "United States" },
    { code: "CA", name: "Canada" },
    // ... (deja tu lista completa tal cual la tenías)
  ].sort((a, b) => a.name.localeCompare(b.name));

  const getSelectedCountry = (callingCode: string) => {
    return phoneCountryCodes.find((c) => c.code === callingCode);
  };

  const cleanPhoneNumber = (phoneNumber: string) => {
    return phoneNumber.replace(/\D/g, "");
  };

  const validatePhoneNumber = (phoneNumber: string, callingCode: string) => {
    const cleanNumber = cleanPhoneNumber(phoneNumber);
    const phoneInfo: any = getPhoneInfo(callingCode);

    if (!phoneInfo?.national_number_pattern) {
      return { isValid: true, error: "" };
    }

    const regex = new RegExp(phoneInfo.national_number_pattern);
    const isValid = regex.test(cleanNumber);

    if (!isValid) {
      return {
        isValid: false,
        error: `Invalid phone number format for ${callingCode}`,
      };
    }

    return { isValid: true, error: "" };
  };

  const validateEmailDomain = (email: string) => {
    const domain = email.toLowerCase().split("@")[1];
    if (!domain) return { isValid: false, error: "Invalid email format" };

    const isBlocked = blockedEmailDomains.blocked_domains.some((d: string) => {
      const clean = d.replace("@", "").toLowerCase();
      return domain === clean;
    });

    if (isBlocked) {
      return {
        isValid: false,
        error:
          "Please use a corporate email address. Personal email providers (Gmail, Yahoo, etc.) are not allowed for company registration.",
      };
    }

    return { isValid: true, error: "" };
  };

  const handleInputChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>
  ) => {
    const { name, value } = e.target;

    setFormData((prev) => ({ ...prev, [name]: value }));

    if (errors[name]) {
      setErrors((prev) => ({ ...prev, [name]: "" }));
    }
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || []);
    setUploadedFiles((prev) => [...prev, ...files]);
  };

  const removeFile = (index: number) => {
    setUploadedFiles((prev) => prev.filter((_, i) => i !== index));
  };

  const handleTaxIdDocumentUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const validTypes = ["application/pdf", "image/jpeg", "image/png", "image/jpg"];
    if (!validTypes.includes(file.type)) {
      setErrors((prev) => ({
        ...prev,
        taxIdDocument: "Please upload a PDF, JPG, or PNG file",
      }));
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      setErrors((prev) => ({
        ...prev,
        taxIdDocument: "File size must be less than 5MB",
      }));
      return;
    }

    setTaxIdDocument(file);
    setErrors((prev) => {
      const next = { ...prev };
      delete next.taxIdDocument;
      return next;
    });
  };

  const removeTaxIdDocument = () => setTaxIdDocument(null);

  // ✅ Email check: usa CONTACT EMAIL (super admin)
  const checkEmailExists = (email: string) => {
    setIsCheckingEmail(true);

    setTimeout(() => {
      if (
        email.includes("@test.com") ||
        email.includes("@existing.com") ||
        email.includes("@gmail.com")
      ) {
        setUserMode("existing_user");
        setExistingUserId("test-user-123");
      } else {
        setUserMode("new_user");
        setExistingUserId(null);
      }
      setIsCheckingEmail(false);
    }, 100);
  };

  const handleOtpChange = (index: number, value: string) => {
    const numericValue = value.replace(/\D/g, "");
    if (numericValue.length > 1) return;

    const newOtp = [...otpCode];
    newOtp[index] = numericValue;
    setOtpCode(newOtp);

    if (numericValue && index < 5) {
      const nextInput = document.getElementById(`otp-${index + 1}`);
      (nextInput as HTMLInputElement | null)?.focus();
    }
  };

  const handleOtpKeyDown = (index: number, e: React.KeyboardEvent) => {
    if (e.key === "Backspace" && !otpCode[index] && index > 0) {
      const prevInput = document.getElementById(`otp-${index - 1}`);
      (prevInput as HTMLInputElement | null)?.focus();
    }

    if (e.key === "v" && (e.ctrlKey || e.metaKey)) {
      e.preventDefault();
      navigator.clipboard.readText().then((text) => {
        const pasted = text.replace(/\D/g, "").slice(0, 6);
        if (pasted.length === 6) {
          setOtpCode(pasted.split(""));
          const lastInput = document.getElementById(`otp-5`);
          (lastInput as HTMLInputElement | null)?.focus();
        }
      });
    }
  };

  // ✅ FIX: validateForm usa contactEmail (no corporateEmail)
  const validateForm = () => {
    const newErrors: Record<string, string> = {};

    if (!formData.companyName.trim()) newErrors.companyName = "Company name is required";
    if (!formData.country) newErrors.country = "Country is required";

    if (!formData.contactEmail.trim()) {
      newErrors.contactEmail = "Contact email is required";
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.contactEmail)) {
      newErrors.contactEmail = "Please enter a valid email address";
    } else {
      const emailValidation = validateEmailDomain(formData.contactEmail);
      if (!emailValidation.isValid) newErrors.contactEmail = emailValidation.error;
    }

    if (!formData.phoneNumber.trim()) {
      newErrors.phoneNumber = "Phone number is required";
    } else if (!/^\+?[\d\s\-\(\)]+$/.test(formData.phoneNumber)) {
      newErrors.phoneNumber = "Please enter a valid phone number";
    }

    if (!formData.password) newErrors.password = "Password is required";
    else if (formData.password.length < 8)
      newErrors.password = "Password must be at least 8 characters long";

    if (!formData.confirmPassword)
      newErrors.confirmPassword = "Please confirm your password";
    else if (formData.password !== formData.confirmPassword)
      newErrors.confirmPassword = "Passwords do not match";

    if (uploadedFiles.length === 0)
      newErrors.documents = "Please upload at least one document";

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e?: React.FormEvent) => {
    e?.preventDefault();
    if (!validateForm()) return;

    setIsLoading(true);
    setTimeout(() => {
      setIsLoading(false);
      setIsSubmitted(true);
    }, 2000);
  };

  const handleGoBack = () => {
    if (cameFromLogin) window.location.href = "/login";
    else window.history.back();
  };

  const handleNext = () => {
    if (currentStep < totalSteps) {
      // ✅ al salir del step 2, verificamos el CONTACT EMAIL
      if (currentStep === 2 && formData.contactEmail) {
        checkEmailExists(formData.contactEmail.trim().toLowerCase());
      }
      setCurrentStep((s) => s + 1);
    }
  };

  const handlePrevious = () => {
    if (currentStep > 1) setCurrentStep((s) => s - 1);
  };

  const validateCurrentStep = () => {
    const newErrors: Record<string, string> = {};

    switch (currentStep) {
      case 1:
        if (!formData.companyName.trim()) newErrors.companyName = "Company name is required";
        if (!formData.country) newErrors.country = "Country is required";
        if (!formData.industry) newErrors.industry = "Industry is required";
        if (!formData.companySize) newErrors.companySize = "Company size is required";
        break;

      case 2:
        if (!formData.contactFirstName.trim()) newErrors.contactFirstName = "First name is required";
        if (!formData.contactLastName.trim()) newErrors.contactLastName = "Last name is required";

        if (!formData.contactEmail.trim()) {
          newErrors.contactEmail = "Contact email is required";
        } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.contactEmail)) {
          newErrors.contactEmail = "Please enter a valid email address";
        } else {
          const emailValidation = validateEmailDomain(formData.contactEmail);
          if (!emailValidation.isValid) newErrors.contactEmail = emailValidation.error;
        }

        if (formData.phoneNumber.trim()) {
          const phoneValidation = validatePhoneNumber(
            formData.phoneNumber,
            formData.phoneCountryCode
          );
          if (!phoneValidation.isValid) newErrors.phoneNumber = phoneValidation.error;
        }
        break;

      case 3: {
        const otpString = otpCode.join("");
        if (!otpString) newErrors.otpCode = "Verification code is required";
        else if (!/^\d{6}$/.test(otpString)) newErrors.otpCode = "Please enter a valid 6-digit code";
        break;
      }

      case 4:
        if (userMode === "new_user") {
          if (!formData.password) newErrors.password = "Password is required";
          else if (formData.password.length < 8)
            newErrors.password = "Password must be at least 8 characters long";

          if (!formData.confirmPassword)
            newErrors.confirmPassword = "Please confirm your password";
          else if (formData.password !== formData.confirmPassword)
            newErrors.confirmPassword = "Passwords do not match";
        }
        break;

      case 5:
        break;
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleStepNext = () => {
    if (!validateCurrentStep()) return;

    if (currentStep === totalSteps) handleSubmit();
    else handleNext();
  };

  // =============================
  // UI: submitted success screen
  // =============================
  if (isSubmitted) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100">
        <div className="bg-white border-b border-gray-200">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex items-center justify-between h-16">
              <div className="flex items-center gap-2">
                <AdaptioMark size={24} color="var(--primary-brand-hex)" />
                <span className="text-lg font-semibold text-gray-900">Adaptio</span>
              </div>
              <span className="text-sm text-gray-500">Account created successfully</span>
            </div>
          </div>
        </div>

        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 h-82">
          <div className="text-center mb-12">
            <div className="w-20 h-20 bg-green-500/20 backdrop-blur-sm rounded-2xl mx-auto mb-6 flex items-center justify-center">
              <CheckCircle className="w-10 h-10 text-green-500" />
            </div>
            <h1 className="text-4xl font-bold text-gray-900 mb-4">Company Account Created!</h1>
            <p className="text-xl text-gray-600 max-w-3xl mx-auto">
              Your company account has been successfully created and is pending verification.
            </p>
          </div>

          <div className="bg-white rounded-2xl shadow-xl border border-gray-200 overflow-hidden">
            <div className="p-8">
              <div className="space-y-6">
                <h2 className="text-2xl font-semibold text-gray-900 mb-6">What happens next?</h2>

                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                  <div className="text-center p-6 bg-green-50 rounded-lg">
                    <div className="w-12 h-12 bg-green-500 rounded-full mx-auto mb-4 flex items-center justify-center">
                      <CheckCircle className="w-6 h-6 text-white" />
                    </div>
                    <h3 className="text-lg font-semibold text-gray-900 mb-2">Verification Required</h3>
                    <p className="text-sm text-gray-600">
                      We'll review your documents and verify your company information within 24-48 hours.
                    </p>
                  </div>

                  <div className="text-center p-6 bg-blue-50 rounded-lg">
                    <div className="w-12 h-12 bg-blue-500 rounded-full mx-auto mb-4 flex items-center justify-center">
                      <Mail className="w-6 h-6 text-white" />
                    </div>
                    <h3 className="text-lg font-semibold text-gray-900 mb-2">Email Confirmation</h3>
                    <p className="text-sm text-gray-600">
                      Check your email for verification instructions and next steps.
                    </p>
                  </div>

                  <div className="text-center p-6 bg-purple-50 rounded-lg">
                    <div className="w-12 h-12 bg-purple-500 rounded-full mx-auto mb-4 flex items-center justify-center">
                      <Lock className="w-6 h-6 text-white" />
                    </div>
                    <h3 className="text-lg font-semibold text-gray-900 mb-2">Access Your Portal</h3>
                    <p className="text-sm text-gray-600">
                      Once verified, you'll receive login credentials to access your company portal.
                    </p>
                  </div>
                </div>
              </div>

              <div className="mt-8 pt-6 border-t border-gray-200">
                <button
                  onClick={handleGoBack}
                  className="w-full flex items-center justify-center gap-2 px-4 h-8 rounded text-white transition-colors text-sm"
                  style={{ backgroundColor: "#404a63" }}
                >
                  <ArrowLeft className="w-4 h-4" />
                  {cameFromLogin ? "Back to Login" : "Go Back"}
                </button>
              </div>

              <div className="mt-6 p-4 bg-gray-50 rounded-lg">
                <div className="flex items-center gap-2 text-sm text-gray-600 mb-2">
                  <Mail className="w-4 h-4" />
                  <span className="font-medium">Need help?</span>
                </div>
                <p className="text-xs text-gray-500">
                  Contact our support team if you have any questions about the verification process.
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // =============================
  // Step content
  // =============================
  const getStepContent = () => {
    switch (currentStep) {
      case 1:
        return (
          <div className="space-y-4">
            {/* Company name */}
            <div>
              <label htmlFor="companyName" className="block text-sm font-medium text-gray-700 mb-2">
                Company Name *
              </label>
              <div className="relative">
                <Building2 className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  id="companyName"
                  name="companyName"
                  type="text"
                  value={formData.companyName}
                  onChange={handleInputChange}
                  className={`w-full pl-10 pr-3 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50 ${
                    errors.companyName ? "border-red-300 focus:ring-red-500" : ""
                  }`}
                  placeholder="Enter your company name"
                  required
                />
              </div>
              {errors.companyName && (
                <p className="mt-1 text-xs text-red-600 flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  {errors.companyName}
                </p>
              )}
            </div>

            {/* Country */}
            <div>
              <label htmlFor="country" className="block text-sm font-medium text-gray-700 mb-2">
                Country *
              </label>
              <div className="relative">
                <Globe className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                <select
                  id="country"
                  name="country"
                  value={formData.country}
                  onChange={handleInputChange}
                  className={`w-full pl-10 pr-3 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50 appearance-none ${
                    errors.country ? "border-red-300 focus:ring-red-500" : ""
                  }`}
                  required
                >
                  <option value="">Select your country</option>
                  {countries.map((c) => (
                    <option key={c.code} value={c.code}>
                      {c.name}
                    </option>
                  ))}
                </select>
              </div>
              {errors.country && (
                <p className="mt-1 text-xs text-red-600 flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  {errors.country}
                </p>
              )}
            </div>

            {/* Company size */}
            <div>
              <label htmlFor="companySize" className="block text-sm font-medium text-gray-700 mb-2">
                Company Size *
              </label>
              <div className="relative">
                <Users className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                <select
                  id="companySize"
                  name="companySize"
                  value={formData.companySize}
                  onChange={handleInputChange}
                  className={`w-full pl-10 pr-3 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50 appearance-none ${
                    errors.companySize ? "border-red-300 focus:ring-red-500" : ""
                  }`}
                  required
                >
                  <option value="">Select company size</option>
                  {companySizeOptions.map((size) => (
                    <option key={size} value={size}>
                      {size}
                    </option>
                  ))}
                </select>
              </div>
              {errors.companySize && (
                <p className="mt-1 text-xs text-red-600 flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  {errors.companySize}
                </p>
              )}
            </div>

            {/* Industry */}
            <div>
              <label htmlFor="industry" className="block text-sm font-medium text-gray-700 mb-2">
                Industry *
              </label>
              <div className="relative">
                <Building className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                <select
                  id="industry"
                  name="industry"
                  value={formData.industry}
                  onChange={handleInputChange}
                  className={`w-full pl-10 pr-3 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50 appearance-none ${
                    errors.industry ? "border-red-300 focus:ring-red-500" : ""
                  }`}
                  required
                >
                  <option value="">Select your industry</option>
                  {industryOptions.map((i) => (
                    <option key={i} value={i}>
                      {i}
                    </option>
                  ))}
                </select>
              </div>
              {errors.industry && (
                <p className="mt-1 text-xs text-red-600 flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  {errors.industry}
                </p>
              )}
            </div>
          </div>
        );

      case 2:
        return (
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label htmlFor="contactFirstName" className="block text-sm font-medium text-gray-700 mb-2">
                  First Name *
                </label>
                <div className="relative">
                  <Users className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    id="contactFirstName"
                    name="contactFirstName"
                    type="text"
                    value={formData.contactFirstName}
                    onChange={handleInputChange}
                    className={`w-full pl-10 pr-3 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50 ${
                      errors.contactFirstName ? "border-red-300 focus:ring-red-500" : ""
                    }`}
                    placeholder="Enter first name"
                    required
                  />
                </div>
                {errors.contactFirstName && (
                  <p className="mt-1 text-xs text-red-600 flex items-center gap-1">
                    <AlertCircle className="w-3 h-3" />
                    {errors.contactFirstName}
                  </p>
                )}
              </div>

              <div>
                <label htmlFor="contactLastName" className="block text-sm font-medium text-gray-700 mb-2">
                  Last Name *
                </label>
                <div className="relative">
                  <Users className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    id="contactLastName"
                    name="contactLastName"
                    type="text"
                    value={formData.contactLastName}
                    onChange={handleInputChange}
                    className={`w-full pl-10 pr-3 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50 ${
                      errors.contactLastName ? "border-red-300 focus:ring-red-500" : ""
                    }`}
                    placeholder="Enter last name"
                    required
                  />
                </div>
                {errors.contactLastName && (
                  <p className="mt-1 text-xs text-red-600 flex items-center gap-1">
                    <AlertCircle className="w-3 h-3" />
                    {errors.contactLastName}
                  </p>
                )}
              </div>
            </div>

            {/* ✅ Contact Email (Super Admin) */}
            <div>
              <label htmlFor="contactEmail" className="block text-sm font-medium text-gray-700 mb-2">
                Contact Email *
              </label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  id="contactEmail"
                  name="contactEmail"
                  type="email"
                  value={formData.contactEmail}
                  onChange={handleInputChange}
                  className={`w-full pl-10 pr-3 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50 ${
                    errors.contactEmail ? "border-red-300 focus:ring-red-500" : ""
                  }`}
                  placeholder="Enter contact email address"
                  required
                />
              </div>
              <p className="mt-1 text-xs text-gray-500">
                This will be the super admin account for your company
              </p>
              {errors.contactEmail && (
                <p className="mt-1 text-xs text-red-600 flex items-start gap-1">
                  <AlertCircle className="w-3 h-3 flex-shrink-0 mt-0.5" />
                  {errors.contactEmail}
                </p>
              )}
            </div>

            {/* Phone */}
            <div>
              <label htmlFor="phoneCountryCode" className="block text-sm font-medium text-gray-700 mb-2">
                Phone Number
              </label>
              <div className="flex gap-2">
                <div className="relative w-32">
                  <Phone className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <select
                    id="phoneCountryCode"
                    name="phoneCountryCode"
                    value={formData.phoneCountryCode}
                    onChange={handleInputChange}
                    className={`w-full pl-10 pr-3 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50 appearance-none ${
                      formData.phoneCountryCode ? "text-transparent" : ""
                    }`}
                  >
                    <option value="">Area Code</option>
                    {phoneCountryCodes.map((country, index) => (
                      <option key={`${country.code}-${country.iso}-${index}`} value={country.code}>
                        {country.iso} {country.flag} {country.code}
                      </option>
                    ))}
                  </select>

                  {formData.phoneCountryCode && (
                    <div className="absolute inset-y-0 left-0 right-0 flex items-center pl-10 pointer-events-none">
                      <span className="text-sm">
                        {getSelectedCountry(formData.phoneCountryCode)?.flag} {formData.phoneCountryCode}
                      </span>
                    </div>
                  )}
                </div>

                <div className="flex-1">
                  <input
                    id="phoneNumber"
                    name="phoneNumber"
                    type="tel"
                    value={formData.phoneNumber}
                    onChange={handleInputChange}
                    className={`w-full px-3 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50 ${
                      errors.phoneNumber ? "border-red-300 focus:ring-red-500" : ""
                    }`}
                    placeholder={(() => {
                      const phoneInfo: any = getPhoneInfo(formData.phoneCountryCode);
                      return phoneInfo?.example_national || "Enter phone number";
                    })()}
                  />
                </div>
              </div>

              {errors.phoneNumber && (
                <p className="mt-1 text-xs text-red-600 flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  {errors.phoneNumber}
                </p>
              )}
            </div>

            {/* Website */}
            <div>
              <label htmlFor="website" className="block text-sm font-medium text-gray-700 mb-2">
                Company Website
              </label>
              <div className="relative">
                <Globe className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  id="website"
                  name="website"
                  type="url"
                  value={formData.website}
                  onChange={handleInputChange}
                  className="w-full pl-10 pr-3 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                  placeholder="https://www.yourcompany.com"
                />
              </div>
            </div>
          </div>
        );

      case 3:
        return (
          <div className="space-y-4">
            <div className="text-center mb-6">
              <div className="w-16 h-16 bg-blue-100 rounded-full mx-auto mb-4 flex items-center justify-center">
                <Mail className="w-8 h-8 text-blue-600" />
              </div>
              <h3 className="text-lg font-semibold text-gray-900 mb-2">Check your email</h3>
              <p className="text-sm text-gray-600">
                We've sent a 6-digit verification code to{" "}
                <strong>{formData.contactEmail}</strong>
              </p>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Verification Code *
              </label>
              <div className="flex gap-3 justify-center">
                {otpCode.map((digit, index) => (
                  <input
                    key={index}
                    id={`otp-${index}`}
                    type="text"
                    inputMode="numeric"
                    pattern="[0-9]"
                    value={digit}
                    onChange={(e) => handleOtpChange(index, e.target.value)}
                    onKeyDown={(e) => handleOtpKeyDown(index, e)}
                    className={`w-12 h-12 text-center text-xl font-semibold border-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary transition-colors ${
                      errors.otpCode
                        ? "border-red-300 focus:ring-red-500"
                        : digit
                        ? "border-green-400 bg-green-50"
                        : "border-gray-300 focus:border-primary"
                    }`}
                    maxLength={1}
                    required
                  />
                ))}
              </div>
              {errors.otpCode && (
                <p className="mt-2 text-xs text-red-600 flex items-center justify-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  {errors.otpCode}
                </p>
              )}
            </div>

            <div className="text-center">
              <button
                type="button"
                className="text-sm text-blue-600 hover:text-blue-800 underline"
                onClick={() => console.log("Resend OTP")}
              >
                Didn't receive the code? Resend
              </button>
            </div>
          </div>
        );

      case 4:
        if (userMode === "existing_user") {
          return (
            <div className="space-y-6">
              <div className="text-center">
                <div className="w-16 h-16 bg-blue-100 rounded-full mx-auto mb-4 flex items-center justify-center">
                  <CheckCircle className="w-8 h-8 text-blue-600" />
                </div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">Account Found</h3>
                <p className="text-sm text-gray-600 mb-4">
                  We found an existing account with <strong>{formData.contactEmail}</strong>
                </p>
                <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                  <p className="text-sm text-blue-800">
                    <strong>You'll use your existing credentials.</strong>
                    <br />
                    No need to create a new password.
                  </p>
                </div>
              </div>
            </div>
          );
        }

        const passwordRequirements = [
          { text: "At least 8 characters", met: formData.password.length >= 8 },
          { text: "One uppercase letter", met: /[A-Z]/.test(formData.password) },
          { text: "One lowercase letter", met: /[a-z]/.test(formData.password) },
          { text: "One number", met: /\d/.test(formData.password) },
          {
            text: "One special character",
            met: /[!@#$%^&*(),.?":{}|<>]/.test(formData.password),
          },
        ];

        return (
          <div className="space-y-4">
            <div>
              <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-2">
                Password *
              </label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  id="password"
                  name="password"
                  type={showPassword ? "text" : "password"}
                  value={formData.password}
                  onChange={handleInputChange}
                  className={`w-full pl-10 pr-10 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50 ${
                    errors.password ? "border-red-300 focus:ring-red-500" : ""
                  }`}
                  placeholder="Enter your new password"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((s) => !s)}
                  className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600 transition-colors"
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
              {errors.password && (
                <p className="mt-1 text-xs text-red-600 flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  {errors.password}
                </p>
              )}
            </div>

            <div>
              <label htmlFor="confirmPassword" className="block text-sm font-medium text-gray-700 mb-2">
                Confirm Password *
              </label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  id="confirmPassword"
                  name="confirmPassword"
                  type={showConfirmPassword ? "text" : "password"}
                  value={formData.confirmPassword}
                  onChange={handleInputChange}
                  className={`w-full pl-10 pr-10 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50 ${
                    errors.confirmPassword ? "border-red-300 focus:ring-red-500" : ""
                  }`}
                  placeholder="Confirm your new password"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowConfirmPassword((s) => !s)}
                  className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600 transition-colors"
                >
                  {showConfirmPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
              {errors.confirmPassword && (
                <p className="mt-1 text-xs text-red-600 flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  {errors.confirmPassword}
                </p>
              )}
            </div>

            <div className="space-y-2">
              <p className="text-sm font-medium text-gray-700">Password Requirements:</p>
              <div className="space-y-1">
                {passwordRequirements.map((req, idx) => (
                  <div key={idx} className="flex items-center gap-2 text-sm">
                    <div
                      className={`w-4 h-4 rounded-full flex items-center justify-center ${
                        req.met ? "bg-green-100" : "bg-gray-100"
                      }`}
                    >
                      {req.met ? (
                        <CheckCircle className="w-3 h-3 text-green-600" />
                      ) : (
                        <div className="w-2 h-2 bg-gray-400 rounded-full" />
                      )}
                    </div>
                    <span className={req.met ? "text-green-600" : "text-gray-500"}>
                      {req.text}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        );

      case 5:
        const taxIdInfo: any = getTaxIdInfo(formData.country);
        return (
          <div className="space-y-4">
            <div>
              <label htmlFor="businessRegistrationNumber" className="block text-sm font-medium text-gray-700 mb-2">
                Business Registration Number / Tax ID{" "}
                {formData.country ? `(${taxIdInfo.tax_id_name})` : ""}
              </label>
              <div className="relative">
                <Hash className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  id="businessRegistrationNumber"
                  name="businessRegistrationNumber"
                  type="text"
                  value={formData.businessRegistrationNumber}
                  onChange={handleInputChange}
                  className="w-full pl-10 pr-3 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                  placeholder={
                    formData.country
                      ? `Enter ${taxIdInfo.tax_id_name} (e.g., ${taxIdInfo.example})`
                      : "Enter registration number or tax ID"
                  }
                />
              </div>
            </div>

            <div>
              <label htmlFor="taxIdDocument" className="block text-sm font-medium text-gray-700 mb-2">
                Upload Business Registration Document
              </label>

              {!taxIdDocument ? (
                <div className="relative">
                  <input
                    id="taxIdDocument"
                    type="file"
                    accept=".pdf,.jpg,.jpeg,.png"
                    onChange={handleTaxIdDocumentUpload}
                    className="hidden"
                  />
                  <label
                    htmlFor="taxIdDocument"
                    className="flex items-center justify-center gap-2 w-full px-3 py-6 border-2 border-dashed rounded text-sm cursor-pointer transition-colors border-gray-300 bg-gray-50 hover:bg-gray-100"
                  >
                    <Upload className="w-4 h-4 text-gray-400" />
                    <span className="text-gray-600">Click to upload or drag and drop</span>
                  </label>
                  <p className="mt-1 text-xs text-gray-500">PDF, JPG, or PNG (max 5MB)</p>
                </div>
              ) : (
                <div className="flex items-center justify-between p-3 bg-gray-50 border border-gray-300 rounded">
                  <div className="flex items-center gap-2 flex-1 min-w-0">
                    <FileText className="w-4 h-4 text-gray-400 flex-shrink-0" />
                    <span className="text-sm text-gray-700 truncate">{taxIdDocument.name}</span>
                    <span className="text-xs text-gray-500 flex-shrink-0">
                      ({(taxIdDocument.size / 1024).toFixed(1)} KB)
                    </span>
                  </div>
                  <button
                    type="button"
                    onClick={removeTaxIdDocument}
                    className="ml-2 p-1 text-gray-400 hover:text-red-600 transition-colors flex-shrink-0"
                  >
                    <X className="w-4 h-4" />
                  </button>
                </div>
              )}
            </div>

            <div>
              <label htmlFor="referralCode" className="block text-sm font-medium text-gray-700 mb-2">
                Referral Code
              </label>
              <input
                id="referralCode"
                type="text"
                value={referralCode}
                onChange={(e) => setReferralCode(e.target.value)}
                className="w-full px-3 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                placeholder="Enter referral code (optional)"
              />
            </div>
          </div>
        );

      default:
        return null;
    }
  };

  // =============================
  // Main layout
  // =============================
  return (
    <div className="min-h-screen flex">
      <div className="w-full lg:w-1/2 flex flex-col bg-white">
        <div className="flex-1 flex flex-col p-8 lg:p-12">
          <div className="w-full max-w-lg mx-auto flex flex-col h-full">
            <div className="flex-shrink-0">
              <div className="mb-10 min-h-[88px] flex flex-col justify-start">
                <h1 className="text-3xl font-bold text-gray-900 mb-2">
                  {currentStep === 1 && "Company Information"}
                  {currentStep === 2 && "Contact Details"}
                  {currentStep === 3 && "Email Verification"}
                  {currentStep === 4 && "Security"}
                  {currentStep === 5 && "Additional Information"}
                </h1>
                <p className="text-sm text-gray-600">
                  {currentStep === 1 && "Tell us about your company"}
                  {currentStep === 2 && "Create your user account and provide contact information"}
                  {currentStep === 3 && "Verify your email address with the code we sent"}
                  {currentStep === 4 && "Create a secure password for your account"}
                  {currentStep === 5 && "Help us understand your business better"}
                </p>
              </div>

              <div className="mb-8">
                <div className="flex items-center justify-between mb-3">
                  <span className="text-xs font-medium text-gray-700">
                    Step {currentStep} of {totalSteps}
                  </span>
                  <span className="text-xs text-gray-500">
                    {Math.round((currentStep / totalSteps) * 100)}% complete
                  </span>
                </div>
                <div className="w-full bg-gray-200 rounded-full h-1.5">
                  <div
                    className="h-1.5 rounded-full transition-all duration-300"
                    style={{
                      width: `${(currentStep / totalSteps) * 100}%`,
                      backgroundColor: "#404a63",
                    }}
                  />
                </div>
              </div>
            </div>

            <div className="flex-1 overflow-y-auto mb-8">{getStepContent()}</div>

            <div className="flex-shrink-0">
              <div className="flex items-center justify-between gap-3">
                {currentStep === 1 ? (
                  <button
                    onClick={handleGoBack}
                    className="flex items-center gap-2 px-4 h-8 rounded text-sm transition-colors text-gray-600 hover:text-gray-800 hover:bg-gray-100"
                  >
                    <ArrowLeft className="w-4 h-4" />
                    {cameFromLogin ? "Back to Login" : "Go Back"}
                  </button>
                ) : (
                  <button
                    onClick={handlePrevious}
                    className="flex items-center gap-2 px-4 h-8 rounded text-sm transition-colors text-gray-600 hover:text-gray-800 hover:bg-gray-100"
                  >
                    <ArrowLeft className="w-4 h-4" />
                    Previous
                  </button>
                )}

                <button
                  onClick={handleStepNext}
                  disabled={isLoading}
                  className="flex items-center gap-2 px-4 h-8 rounded text-white transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                  style={{ backgroundColor: "#404a63" }}
                >
                  {isLoading ? (
                    <>
                      <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                      Processing...
                    </>
                  ) : (
                    <>
                      {currentStep === totalSteps ? "Create Account" : "Continue"}
                      <ArrowRight className="w-4 h-4" />
                    </>
                  )}
                </button>
              </div>
            </div>

            {/* (Opcional) Documents uploader - si lo estás usando en otro step, conecta estos handlers */}
            {/* <input type="file" multiple onChange={handleFileUpload} /> */}
            {/* {uploadedFiles.map((f, i) => <button onClick={() => removeFile(i)}>remove</button>)} */}
          </div>
        </div>
      </div>

      <div
        className="hidden lg:flex lg:w-1/2 flex-col items-center justify-center p-12"
        style={{ backgroundColor: "#404a63" }}
      >
        <div className="w-full max-w-md">
          <div className="text-center mb-12">
            <div className="flex items-center justify-center gap-2 mb-6">
              <AdaptioMark size={32} color="var(--primary-brand-hex)" />
              <span className="text-2xl font-semibold text-white">Adaptio</span>
            </div>
            <h2 className="text-2xl font-bold text-white mb-2">Company Registration</h2>
            <p className="text-sm text-white/70">
              Create your company portal to manage your workforce
            </p>
          </div>

          <div className="bg-white rounded-xl p-8 shadow-sm mb-8">
            <div className="space-y-3">
              {["Company Information", "Contact Details", "Email Verification", "Security", "Additional Information"].map(
                (label, idx) => {
                  const step = idx + 1;
                  const done = currentStep > step;
                  const active = currentStep === step;

                  return (
                    <div key={label} className="flex items-center gap-3">
                      <div
                        className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-medium ${
                          done
                            ? "bg-green-100 text-green-700"
                            : active
                            ? "text-white"
                            : "bg-gray-100 text-gray-400"
                        }`}
                        style={active ? { backgroundColor: "#404a63" } : {}}
                      >
                        {done ? "✓" : String(step)}
                      </div>
                      <span className={`text-sm ${currentStep >= step ? "text-gray-900 font-medium" : "text-gray-500"}`}>
                        {label}
                      </span>
                    </div>
                  );
                }
              )}
            </div>
          </div>

          <div className="text-center">
            <p className="text-xs text-white/70">
              Need assistance? Contact our support team at{" "}
              <a href="mailto:support@rhemo.com" className="underline hover:text-white">
                support@rhemo.com
              </a>
              , or go back to our{" "}
              <a href="/login" className="underline hover:text-white">
                login
              </a>{" "}
              page.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
