using FluentValidation;
using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.CustomerCommands.Add
{
    public class AddCustomerCommand : IRequest<bool>
    {
        public CreateCustomerRequest Request { get; set; }
        public int CompanyId { get; }

        public AddCustomerCommand(CreateCustomerRequest createCustomerRequest, int companyId)
        {
            Request = createCustomerRequest;
            CompanyId = companyId;
        }
        public class AddCustomerCommandHandler : IRequestHandler<AddCustomerCommand, bool>
        {
            private readonly CustomerService _customerService;
            public AddCustomerCommandHandler(CustomerService customerService)
            {
                _customerService = customerService;
            }
            public async Task<bool> Handle(AddCustomerCommand request, CancellationToken cancellationToken)
            {
                return await _customerService.CreateAsync(request.Request, request.CompanyId);
            }
        }
        public class AddCustomerCommandValidator : AbstractValidator<AddCustomerCommand>
        {
            public AddCustomerCommandValidator()
            {
                RuleFor(c => c.Request.Name).NotNull().NotEmpty().WithMessage("Customer name is required.");
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}
