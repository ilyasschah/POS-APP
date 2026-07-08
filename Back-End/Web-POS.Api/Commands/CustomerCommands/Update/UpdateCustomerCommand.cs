using FluentValidation;
using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.CustomerCommands.Update
{
    public class UpdateCustomerCommand : IRequest<bool>
    {
        public UpdateCustomerRequest Request { get; }
        public int CompanyId { get; }

        public UpdateCustomerCommand(UpdateCustomerRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateCustomerCommandHandler : IRequestHandler<UpdateCustomerCommand, bool>
        {
            private readonly CustomerService _customerService;

            public UpdateCustomerCommandHandler(CustomerService customerService)
            {
                _customerService = customerService;
            }
            public Task<bool> Handle(UpdateCustomerCommand command, CancellationToken cancellationToken)
            {
                return _customerService.UpdateAsync(command.Request, command.CompanyId);
            }
        }
        public class UpdateCustomerCommandValidator : AbstractValidator<UpdateCustomerCommand>
        {
            public UpdateCustomerCommandValidator()
            {
                RuleFor(c => c.Request.Id).GreaterThan(0).WithMessage("Id must be valid.");
                RuleFor(c => c.Request.Name).NotNull().NotEmpty().WithMessage("Customer name is required.");
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}
