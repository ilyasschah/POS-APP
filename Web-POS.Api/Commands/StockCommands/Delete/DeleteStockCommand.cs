using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.StockCommands.Delete
{
    public class DeleteStockCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public int CompanyId { get; }

        public DeleteStockCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class DeleteStockCommandHandler : IRequestHandler<DeleteStockCommand, bool>
        {
            private readonly StockService _stockService;
            public DeleteStockCommandHandler(StockService stockService)
            {
                _stockService = stockService;
            }
            public Task<bool> Handle(DeleteStockCommand request, CancellationToken cancellationToken)
            {
                return _stockService.Delete(request.Id, request.CompanyId);
            }
        }
    }
    public class DeleteStockCommandValidator : AbstractValidator<DeleteStockCommand>
    {
        public DeleteStockCommandValidator()
        {
            RuleFor(sid => sid.Id).GreaterThan(0).WithMessage("Stock ID must be valid.");
            RuleFor(cid => cid.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}

