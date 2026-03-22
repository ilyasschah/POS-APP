using FluentValidation;
using MediatR;
using Api.Services;

namespace Api.Commands.CustomerCommands.Delete
{
    public class DeleteCustomerCommand : IRequest<bool>
    {
        public int Id { get; }
        public int CompanyId { get; }
        public DeleteCustomerCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }
        public class DeleteCustomerCommandHandler : IRequestHandler<DeleteCustomerCommand, bool>
        {
            private readonly CustomerService _service;
            public DeleteCustomerCommandHandler(CustomerService service)
            {
                _service = service;
            }
            public Task<bool> Handle(DeleteCustomerCommand request, CancellationToken cancellationToken)
            {
                return _service.DeleteAsync(request.Id, request.CompanyId);
            }
        }
        public class DeleteCustomerCommandValidator : AbstractValidator<DeleteCustomerCommand>
        {
            public DeleteCustomerCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0).WithMessage("Id must be valid.");
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("CompanyId must be valid.");
            }
        }
    }
}
