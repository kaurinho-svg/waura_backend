import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LegalDocScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalDocScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ),
    );
  }

  static const String privacyPolicy = """
## Privacy Policy

**Effective Date:** January 1, 2024

**1. Introduction**
Welcome to Waura ("we," "our," or "us"). We respect your privacy and are committed to protecting your personal data. This privacy policy will inform you as to how we look after your personal data when you visit our application and tell you about your privacy rights and how the law protects you.

**2. Data We Collect**
We may collect, use, store and transfer different kinds of personal data about you which we have grouped together follows:
*   **Identity Data:** includes first name, last name, username or similar identifier.
*   **Contact Data:** includes email address and telephone numbers.
*   **Technical Data:** includes internet protocol (IP) address, your login data, browser type and version, time zone setting and location, browser plug-in types and versions, operating system and platform and other technology on the devices you use to access this website.
*   **Profile Data:** includes your username and password, purchases or orders made by you, your interests, preferences, feedback and survey responses.
*   **Usage Data:** includes information about how you use our website, products and services.
*   **Biometric Data (Virtual Try-On):** To provide our Virtual Try-On feature, we process facial and body images you upload. These images are processed temporarily to generate the Try-On result and are stored in your private history if you choose to save them.

**3. How We Use Your Data**
We will only use your personal data when the law allows us to. Most commonly, we will use your personal data in the following circumstances:
*   Where we need to perform the contract we are about to enter into or have entered into with you.
*   Where it is necessary for our legitimate interests (or those of a third party) and your interests and fundamental rights do not override those interests.
*   Where we need to comply with a legal or regulatory obligation.

**4. Data Security**
We have put in place appropriate security measures to prevent your personal data from being accidentally lost, used or accessed in an unauthorised way, altered or disclosed.

**5. Contact Us**
If you have any questions about this privacy policy or our privacy practices, please contact us at: support@waura.app
""";

  static const String termsOfService = """
## Terms of Service

**1. Agreement to Terms**
By using our application, you agree to be bound by these Terms. If you don't agree to be bound by these Terms, do not use the Services.

**2. Description of Services**
Waura provides an AI-powered personal stylist and virtual try-on service.

**3. User Accounts**
When you create an account with us, you must provide us information that is accurate, complete, and current at all times. Failure to do so constitutes a breach of the Terms, which may result in immediate termination of your account on our Service.

**4. Intellectual Property**
The Service and its original content (excluding Content provided by users), features and functionality are and will remain the exclusive property of Waura and its licensors.

**5. Termination**
We may terminate or suspend your account immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach the Terms.

**6. Limitation of Liability**
In no event shall Waura, nor its directors, employees, partners, agents, suppliers, or affiliates, be liable for any indirect, incidental, special, consequential or punitive damages, including without limitation, loss of profits, data, use, goodwill, or other intangible losses, resulting from (i) your access to or use of or inability to access or use the Service; (ii) any conduct or content of any third party on the Service; (iii) any content obtained from the Service; and (iv) unauthorized access, use or alteration of your transmissions or content, whether based on warranty, contract, tort (including negligence) or any other legal theory, whether or not we have been informed of the possibility of such damage, and even if a remedy set forth herein is found to have failed of its essential purpose.

**7. Changes**
We reserve the right, at our sole discretion, to modify or replace these Terms at any time. If a revision is material we will try to provide at least 30 days notice prior to any new terms taking effect. What constitutes a material change will be determined at our sole discretion.

**8. Contact Us**
If you have any questions about these Terms, please contact us at support@waura.app
""";
}
